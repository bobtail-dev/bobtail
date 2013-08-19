if typeof exports is 'undefined'
  @rx = rx = {}
else
  rx = exports

nextUid = 0
mkuid = -> nextUid += 1

popKey = (x, k) ->
  if not k of x
    throw 'object has no key ' + k
  v = x[k]
  delete x[k]
  v

nthWhere = (xs, n, f) ->
  for x,i in xs
    if f(x) and (n -= 1) < 0
      return [x, i]
  [null, -1]

maybe = (f,x) ->
  if x? then f(x) else x

firstWhere = (xs, f) -> nthWhere(xs, 0, f)

mkMap = -> Object.create(null)

#
# Reactivity
#

Recorder = class rx.Recorder
  constructor: ->
    @stack = []
  # takes a dep cell and push it onto the stack as the current invalidation
  # listener, so that calls to .sub (e.g. by ObsCell.get) can establish a
  # dependency
  start: (dep) ->
    _(@stack).last().addNestedBind(dep) if @stack.length > 0
    @stack.push(dep)
  stop: ->
    @stack.pop()
  # Takes a subscriber function that adds the current cell as an invalidation
  # listener; the subscriber function is responsible for actually subscribing
  # the current listener to the appropriate events; note that we are
  # establishing both directions of the dependency tracking here (subscribing
  # to the dependency's events as well as registering the subscription UID with
  # the current listener)
  sub: (sub) ->
    if @stack.length > 0
      topCell = _(@stack).last()
      handle = sub(topCell)
      topCell.addSub(handle)
  warnMutate: ->
    if @stack.length > 0
      console.warn('Mutation to observable detected during a bind context')

recorder = new Recorder()

rx.bind = bind = (f) ->
  dep = new DepCell(f)
  dep.refresh()
  dep

rx.lagBind = lagBind = (init, f) ->
  dep = new DepCell(f, init)
  dep.refresh()
  dep

# Just a global mapping from subscription UIDs to source Evs; this essentially
# enables us to follow subscription UIDs up the dependency graph (from
# dependents)
DepMgr = class rx.DepMgr
  constructor: ->
    @uid2src = {}
  # called by source Ev to register a new subscription
  sub: (uid, src) ->
    @uid2src[uid] = src
  # called by destination (who's responsible for remembering what he's
  # subscribed to, or else...memory leak!)
  unsub: (uid) ->
    @uid2src[uid].unsub(uid)
    popKey(@uid2src, uid)

depMgr = new DepMgr()

Ev = class rx.Ev
  constructor: (@inits) ->
    @subs = []
  sub: (listener) ->
    uid = mkuid()
    if @inits?
      for init in @inits()
        listener(init)
    @subs[uid] = listener
    depMgr.sub(uid, this)
    uid
  # callable only by the src
  pub: (data) ->
    for uid, listener of @subs
      listener(data)
  unsub: (uid) ->
    popKey(@subs, uid)

ObsCell = class rx.ObsCell
  constructor: (@x) ->
    @x = @x ? null
    @onSet = new Ev(=> [[null, @x]]) # [old, new]
  get: ->
    recorder.sub((target) => @onSet.sub(-> target.refresh()))
    @x

SrcCell = class rx.SrcCell extends ObsCell
  set: (x) ->
    recorder.warnMutate()
    old = @x
    @x = x
    @onSet.pub([old, x])
    old

DepCell = class rx.DepCell extends ObsCell
  constructor: (@body, init, lag) ->
    super(init ? null)
    @subs = []
    @refreshing = false
    @lag = lag ? false
    @timeout = null
    @nestedBinds = []
  refresh: ->
    realRefresh = =>
      #console.log('real refresh')
      if not @refreshing
        old = @x
        @disconnect()
        recorder.start(this)
        @refreshing = true
        try
          @x = @body()
        finally
          @refreshing = false
          recorder.stop()
        @onSet.pub([old, @x])
    if not @refreshing
      if @lag
        if @timeout?
          clearTimeout(@timeout)
        console.log('setting timeout')
        @timeout = setTimeout(realRefresh, 500)
      else
        realRefresh()
  # unsubscribe from all dependencies and recursively have all nested binds
  # disconnect themselves as well
  disconnect: ->
    for subUid in @subs
      depMgr.unsub(subUid)
    for nestedBind in @nestedBinds
      nestedBind.disconnect()
    @subs = []
    @nestedBinds = []
  # called by recorder
  addSub: (subUid) ->
    @subs.push(subUid)
  # called by recorder
  addNestedBind: (nestedBind) ->
    @nestedBinds.push(nestedBind)

ObsArray = class rx.ObsArray
  constructor: (@xs) ->
    @xs = @xs ? []
    @onChange = new Ev(=> [[0, [], @xs]]) # [index, removed, added]
  all: ->
    recorder.sub((target) => @onChange.sub(-> target.refresh()))
    _.clone(@xs)
  raw: ->
    recorder.sub((target) => @onChange.sub(-> target.refresh()))
    @xs
  at: (i) ->
    recorder.sub((target) => @onChange.sub(([index, removed, added]) ->
      target.refresh() if index == i))
    @xs[i]
  length: ->
    recorder.sub((target) => @onChange.sub(([index, removed, added]) ->
      target.refresh() if removed.length != added.length))
    @xs.length
  map: (f) ->
    ys = new MappedDepArray()
    @onChange.sub(([index, removed, added]) ->
      ys.realSplice(index, removed.length, added.map(f))
    )
    ys
  realSplice: (index, count, additions) ->
    removed = @xs.splice.apply(@xs, [index, count].concat(additions))
    @onChange.pub([index, removed, additions])

SrcArray = class rx.SrcArray extends ObsArray
  spliceArray: (index, count, additions) ->
    recorder.warnMutate()
    @realSplice(index, count, additions)
  splice: (index, count, additions...) -> @spliceArray(index, count, additions)
  insert: (x, index) -> @splice(index, 0, x)
  remove: (x) -> @removeAt(_(@all()).indexOf(x))
  removeAt: (index) -> @splice(index, 1)
  push: (x) -> @splice(@length(), 0, x)
  put: (i, x) -> @splice(i, 1, x)
  replace: (xs) -> @spliceArray(0, @length(), xs)

MappedDepArray = class rx.MappedDepArray extends ObsArray

DepArray = class rx.DepArray extends ObsArray
  constructor: (@f) ->
    super()
    (bind => @f()).onSet.sub(([old, val]) =>
      if old?
        # TODO use diff algo so shifts aren't catastrophic
        [index, index] = firstWhere(
          [0..Math.min(old.length, val.length)],
          (i) -> old[i] != val[i]
        )
      else
        index = 0
      if index > -1 # if found any diffs
        count = if old? then old.length - index else 0
        additions = val[index..]
        @realSplice(index, count, additions)
    )

ObsMap = class rx.ObsMap
  constructor: (@x = {}) ->
    @onAdd = new Ev(=> ([k,v] for k,v of x)) # [key, new]
    @onRemove = new Ev() # [key, old]
    @onChange = new Ev() # [key, old, new]
  get: (key) ->
    recorder.sub((target) => @onAdd.sub(([subkey, val]) ->
      target.refresh() if key == subkey))
    recorder.sub((target) => @onChange.sub(([subkey, old, val]) ->
      target.refresh() if key == subkey))
    recorder.sub((target) => @onRemove.sub(([subkey, old]) ->
      target.refresh() if key == subkey))
    @x[key]
  all: ->
    recorder.sub((target) => @onAdd.sub(-> target.refresh()))
    recorder.sub((target) => @onChange.sub(-> target.refresh()))
    recorder.sub((target) => @onRemove.sub(-> target.refresh()))
    _.clone(@x)
  realPut: (key, val) ->
    if key of @x
      old = @x[key]
      @x[key] = val
      @onChange.pub([key, old, val])
      old
    else
      @x[key] = val
      @onAdd.pub([key, val])
      undefined
  realRemove: (key) ->
    val = popKey(@x, key)
    @onRemove.pub([key, val])
    val

SrcMap = class rx.SrcMap extends ObsMap
  put: (key, val) ->
    recorder.warnMutate()
    @realPut(key, val)
  remove: (key) ->
    recorder.warnMutate()
    @realRemove(key)

DepMap = class rx.DepMap extends ObsMap
  constructor: (@f) ->
    super()
    new DepCell(@f).onSet.sub(([old, val]) ->
      for k,v of old
        if not k of val
          @realRemove(k)
      for k,v of val
        if @x[k] != v
          @realPut(k,v)
    )

#
# Implicitly reactive objects
#

rx.reactify = (obj, fieldspec) ->
  if _.isArray(obj)
    arr = rx.array(_.clone(obj))
    Object.defineProperties obj, _.object(
      for methName in _.functions(arr) when methName != 'length'
        do (methName) ->
          meth = obj[methName]
          newMeth = (args...) ->
            res = meth.call(obj, args...) if meth?
            arr[methName].call(arr, args...)
            res
          spec =
            configurable: true
            enumerable: false
            value: newMeth
            writable: true
          [methName, spec]
    )
    obj
  else
    Object.defineProperties obj, _.object(
      for name, spec of fieldspec
        do (name, spec) ->
          desc = null
          switch spec.type
            when 'cell'
              obs = rx.cell(spec.val ? null)
              desc =
                configurable: true
                enumerable: true
                get: -> obs.get()
                set: (x) -> obs.set(x)
            when 'array'
              view = rx.reactify(spec.val ? [])
              desc =
                configurable: true
                enumerable: true
                get: ->
                  view.raw()
                  view
                set: (x) ->
                  view.splice(0, view.length, x...)
                  view
            else throw "Unknown observable type: #{type}"
          [name, desc]
    )

rx.autoReactify = (obj) ->
  rx.reactify obj, _.object(
    for name in Object.getOwnPropertyNames(obj)
      val = obj[name]
      type =
        if _.isFunction(val) then null
        else if _.isArray(val) then 'array'
        else 'cell'
      [name, {type, val}]
  )

_.extend(rx, {
  cell: (x) -> new SrcCell(x)
  array: (xs) -> new SrcArray(xs)
  map: (x) -> new SrcMap(x)
})

#
# Reactive utilities
#

rx.flatten = (xs) ->
  new DepArray -> _(
    for x in xs
      if x instanceof ObsArray
        x.raw()
      else if x instanceof ObsCell
        x.get()
      else
        x
  ).chain().flatten(true).filter((x) -> x?).value()

#
# jQuery extension
#

$.fn.rx = (prop) ->
  map = @data('rx-map')
  if not map? then @data('rx-map', map = mkMap())
  if prop of map then return map[prop]
  map[prop] =
    switch prop
      when 'focused'
        focused = rx.cell(@is(':focus'))
        @focus -> focused.set(true)
        @blur -> focused.set(false)
        focused
      when 'val'
        val = rx.cell(@val())
        @change => val.set(@val())
        @on 'input', => val.set(@val())
        val
      when 'checked'
        checked = rx.cell(@is(':checked'))
        @change => checked.set(@is(':checked'))
        checked
      else
        throw 'Unknown reactive property type'

#
# reactive template DSL
#

if typeof exports is 'undefined'
  @rxt = rxt = {}
else
  rxt = exports

RawHtml = class rxt.RawHtml
  constructor: (@html) ->

# jQuery events are special attrs, along with `init`

events = ["blur", "change", "click", "dblclick", "error", "focus", "focusin",
  "focusout", "hover", "keydown", "keypress", "keyup", "load", "mousedown",
  "mouseenter", "mouseleave", "mousemove", "mouseout", "mouseover", "mouseup",
  "ready", "resize", "scroll", "select", "submit", "toggle", "unload"]

specialAttrs = rxt.specialAttrs = {
  init: (elt, fn) -> fn.call(elt)
}

for ev in events
  do (ev) ->
    specialAttrs[ev] = (elt, fn) -> elt[ev]((e) -> fn.call(elt, e))

# attr vs prop:
# http://blog.jquery.com/2011/05/10/jquery-1-6-1-rc-1-released/
# http://api.jquery.com/prop/

props = ['async', 'autofocus', 'checked', 'location', 'multiple', 'readOnly',
  'selected', 'selectedIndex', 'tagName', 'nodeName', 'nodeType',
  'ownerDocument', 'defaultChecked', 'defaultSelected']
propSet = _.object([prop, null] for prop in props)

setProp = (elt, prop, val) ->
  if prop == 'value'
    elt.val(val)
  else if prop of propSet
    elt.prop(prop, val)
  else
    elt.attr(prop, val)

rxt.mktag = mktag = (tag) ->
  (arg1, arg2) ->
    # arguments are either (), (attrs: Object), (contents: non-Object), or
    # (attrs: Object, contents: non-Object)
    [attrs, contents] =
      if not arg1? and not arg2?
        [{}, null]
      else if arg2?
        [arg1, arg2]
      else if _.isString(arg1) or arg1 instanceof RawHtml or _.isArray(arg1) or
              arg1 instanceof ObsCell or arg1 instanceof ObsArray
        [{}, arg1]
      else
        [arg1, null]

    elt = $("<#{tag}/>")
    for name, value of _.omit(attrs, _.keys(specialAttrs))
      if value instanceof ObsCell
        do (name) ->
          value.onSet.sub ([old, val]) ->
            setProp(elt, name, val)
      else
        setProp(elt, name, value)
    if contents?
      toNodes = (contents) ->
        for child in contents
          if _.isString(child)
            document.createTextNode(child)
          else if child instanceof RawHtml
            parsed = $(child.html)
            throw 'Cannot insert RawHtml of multiple elements' if parsed.length
            parsed[0]
          else if child instanceof $
            child[0]
          else
            throw 'Unknown element type in array: ' + child.constructor.name
      updateContents = (contents) ->
        elt.html('')
        if _.isArray(contents)
          elt.append(toNodes(contents))
        else if _.isString(contents) or contents instanceof RawHtml
          updateContents([contents])
        else
          throw 'Unknown type for contents: ' + contents.constructor.name
      if contents instanceof ObsArray
        contents.onChange.sub(([index, removed, added]) ->
          elt.contents().slice(index, index + removed.length).remove()
          toAdd = toNodes(added)
          if index == elt.contents().length
            elt.append(toAdd)
          else
            elt.contents().eq(index).before(toAdd)
        )
      else if contents instanceof ObsCell
        # TODO: make this more efficient by checking each element to see if it
        # changed (i.e. layer a MappedDepArray over this, and make DepArrays
        # propagate the minimal change set)
        contents.onSet.sub(([old, val]) ->
          updateContents(val))
      else
        updateContents(contents)
    for key of attrs when key of specialAttrs
      specialAttrs[key](elt, attrs[key], attrs, contents)
    elt

# From <https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/HTML5/HTML5_element_list>
#
# Extract with:
#
#     "['"+document.body.innerText.match(/<.*?>/g).map(function(x){return x.substring(1, x.length-1);}).join("', '")+"']";

tags = ['html', 'head', 'title', 'base', 'link', 'meta', 'style', 'script',
  'noscript', 'body', 'body', 'section', 'nav', 'article', 'aside', 'h1', 'h2',
  'h3', 'h4', 'h5', 'h6', 'h1', 'h6', 'header', 'footer', 'address', 'main',
  'main', 'p', 'hr', 'pre', 'blockquote', 'ol', 'ul', 'li', 'dl', 'dt', 'dd',
  'dd', 'figure', 'figcaption', 'div', 'a', 'em', 'strong', 'small', 's',
  'cite', 'q', 'dfn', 'abbr', 'data', 'time', 'code', 'var', 'samp', 'kbd',
  'sub', 'sup', 'i', 'b', 'u', 'mark', 'ruby', 'rt', 'rp', 'bdi', 'bdo',
  'span', 'br', 'wbr', 'ins', 'del', 'img', 'iframe', 'embed', 'object',
  'param', 'object', 'video', 'audio', 'source', 'video', 'audio', 'track',
  'video', 'audio', 'canvas', 'map', 'area', 'area', 'map', 'svg', 'math',
  'table', 'caption', 'colgroup', 'col', 'tbody', 'thead', 'tfoot', 'tr', 'td',
  'th', 'form', 'fieldset', 'legend', 'fieldset', 'label', 'input', 'button',
  'select', 'datalist', 'optgroup', 'option', 'select', 'datalist', 'textarea',
  'keygen', 'output', 'progress', 'meter', 'details', 'summary', 'details',
  'menuitem', 'menu']

rxt.tags = _.object([tag, rxt.mktag(tag)] for tag in tags)
rxt.rawHtml = (html) -> new RawHtml(html)
rxt.importTags = (x) => _(x ? this).extend(rxt.tags)
