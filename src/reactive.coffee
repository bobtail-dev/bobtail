if typeof exports is 'undefined'
  @rx = rx = {}
else
  rx = exports

nextUid = 0
mkuid = -> nextUid += 1

popKey = (x, k) ->
  if k not of x
    throw new Error('object has no key ' + k)
  v = x[k]
  delete x[k]
  v

nthWhere = (xs, n, f) ->
  for x,i in xs
    if f(x) and (n -= 1) < 0
      return [x, i]
  [null, -1]

firstWhere = (xs, f) -> nthWhere(xs, 0, f)

mkMap = (xs = []) ->
  map = if Object.create? then Object.create(null) else {}
  if _.isArray(xs)
    map[k] = v for [k,v] in xs
  else
    map[k] = v for k,v of xs
  map

sum = (xs) ->
  n = 0
  n += x for x in xs
  n

#
# Events and pub-sub dependency management
#

# Just a global mapping from subscription UIDs to source Evs; this essentially
# enables us to follow subscription UIDs up the dependency graph (from
# dependents)
DepMgr = class rx.DepMgr
  constructor: ->
    @uid2src = {}
    @buffering = false
    @buffer = []
  # called by Ev.sub to register a new subscription
  sub: (uid, src) ->
    @uid2src[uid] = src
  # called by Ev.unsub to unregister a subscription
  unsub: (uid) ->
    popKey(@uid2src, uid)
  # transactions
  transaction: (f) ->
    @buffering = true
    try
      res = f()
    finally
      b() for b in @buffer
      @buffer = []
      @buffering = false
    res

rx._depMgr = depMgr = new DepMgr()

Ev = class rx.Ev
  constructor: (@inits) ->
    @subs = mkMap()
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
    if depMgr.buffering
      depMgr.buffer.push => @pub(data)
    else
      for uid, listener of @subs
        listener(data)
  unsub: (uid) ->
    popKey(@subs, uid)
    depMgr.unsub(uid, this)
  # listener is subscribed only for the duration of the context
  scoped: (listener, context) ->
    uid = @sub(listener)
    try context()
    finally @unsub(uid)

rx.skipFirst = (f) ->
  first = true
  (args...) ->
    if first
      first = false
    else
      f(args...)

#
# Reactivity
#

Recorder = class rx.Recorder
  constructor: ->
    @stack = []
    @isMutating = false
    @isIgnoring = false
    @onMutationWarning = new Ev() # just fires null for now
  # takes a dep cell and push it onto the stack as the current invalidation
  # listener, so that calls to .sub (e.g. by ObsCell.get) can establish a
  # dependency
  record: (dep, f) ->
    _(@stack).last().addNestedBind(dep) if @stack.length > 0 and not @isMutating
    @stack.push(dep)
    # reset isMutating
    wasMutating = @isMutating
    @isMutating = false
    # reset isIgnoring
    wasIgnoring = @isIgnoring
    @isIgnoring = false
    try
      f()
    finally
      @isIgnoring = wasIgnoring
      @isMutating = wasMutating
      @stack.pop()
  # Takes a subscriber function that adds the current cell as an invalidation
  # listener; the subscriber function is responsible for actually subscribing
  # the current listener to the appropriate events; note that we are
  # establishing both directions of the dependency tracking here (subscribing
  # to the dependency's events as well as registering the subscription UID with
  # the current listener)
  sub: (sub) ->
    if @stack.length > 0 and not @isIgnoring
      topCell = _(@stack).last()
      handle = sub(topCell)
  addCleanup: (cleanup) ->
    _(@stack).last().addCleanup(cleanup) if @stack.length > 0
  # Delimit the function as one where a mutation takes place, such that if
  # within this function we refresh a bind, we don't treat that bind as a
  # nested bind (which causes all sorts of problems e.g. the cascading
  # disconnects)
  mutating: (f) ->
    if @stack.length > 0
      console.warn('Mutation to observable detected during a bind context')
      @onMutationWarning.pub(null)
    wasMutating = @isMutating
    @isMutating = true
    try f()
    finally @isMutating = wasMutating
  # Ignore event hooks while evaluating f (but limited to the current bind
  # context; subsequent binds will still subscribe those binds to event hooks)
  ignoring: (f) ->
    wasIgnoring = @isIgnoring
    @isIgnoring = true
    try f()
    finally @isIgnoring = wasIgnoring

rx._recorder = recorder = new Recorder()

rx.asyncBind = asyncBind = (init, f) ->
  dep = new DepCell(f, init)
  dep.refresh()
  dep

rx.bind = bind = (f) ->
  asyncBind null, -> @done(@record(f))

rx.lagBind = lagBind = (lag, init, f) ->
  timeout = null
  asyncBind init, ->
    clearTimeout(timeout) if timeout?
    timeout = setTimeout(
      => @done(@record(f))
      lag
    )

rx.postLagBind = postLagBind = (init, f) ->
  timeout = null
  asyncBind init, ->
    {val, ms} = @record(f)
    clearTimeout(timeout) if timeout?
    timeout = setTimeout((=> @done(val)), ms)

rx.snap = (f) -> recorder.ignoring(f)

rx.onDispose = (cleanup) -> recorder.addCleanup(cleanup)

rx.autoSub = (ev, listener) ->
  subid = ev.sub(listener)
  rx.onDispose -> ev.unsub(subid)
  subid

ObsCell = class rx.ObsCell
  constructor: (@x) ->
    @x = @x ? null
    @onSet = new Ev(=> [[null, @x]]) # [old, new]
  get: ->
    recorder.sub (target) => rx.autoSub @onSet, -> target.refresh()
    @x

SrcCell = class rx.SrcCell extends ObsCell
  set: (x) -> recorder.mutating =>
    if @x != x
      old = @x
      @x = x
      @onSet.pub([old, x])
      old

DepCell = class rx.DepCell extends ObsCell
  constructor: (@body, init) ->
    super(init ? null)
    @refreshing = false
    @nestedBinds = []
    @cleanups = []
  refresh: ->
    if not @refreshing
      old = @x
      # TODO we are immediately disconnecting; something that disconnects upon
      # completion may have better semantics for asynchronous operations:
      #
      # - enabling lagBind to defer evaluation so long as its current
      #   dependencies keep changing
      # - allowing nested binds to continue reacting during asynchronous
      #   operation
      #
      # But the implementation is more complex as it requires being able to
      # create and discard tentative recordings.  It's also unclear whether
      # such a lagBind is more desirable (in the face of changing dependencies)
      # and whether on-completion is what's most generalizable.
      realDone = (@x) => @onSet.pub([old, @x])
      recorded: false
      syncResult = null
      isSynchronous = false
      env =
        # next two are for tolerating env.done calls from within env.record
        record: (f) =>
          # TODO document why @refreshing exists
          # guards against recursively evaluating this recorded
          # function (@body or an async body) when calling `.get()`
          if not @refreshing
            @disconnect()
            throw new Error('this refresh has already recorded its dependencies') if recorded
            @refreshing = true
            recorded = true
            try res = recorder.record @, -> f.call(env)
            finally @refreshing = false
            realDone(syncResult) if isSynchronous
            res
        done: (x) =>
          if old != x
            if @refreshing
              isSynchronous = true
              syncResult = x
            else
              realDone(x)
      @body.call(env)
  # unsubscribe from all dependencies and recursively have all nested binds
  # disconnect themselves as well
  disconnect: ->
    # TODO ordering of cleanup vs unsubscribes may require revisiting
    for cleanup in @cleanups
      cleanup()
    for nestedBind in @nestedBinds
      nestedBind.disconnect()
    @nestedBinds = []
    @cleanups = []
  # called by recorder
  addNestedBind: (nestedBind) ->
    @nestedBinds.push(nestedBind)
  # called by recorder
  addCleanup: (cleanup) ->
    @cleanups.push(cleanup)

ObsArray = class rx.ObsArray
  constructor: (@xs = [], @diff = rx.basicDiff()) ->
    @onChange = new Ev(=> [[0, [], @xs]]) # [index, removed, added]
    @indexed_ = null
  all: ->
    recorder.sub (target) => rx.autoSub @onChange, -> target.refresh()
    _.clone(@xs)
  raw: ->
    recorder.sub (target) => rx.autoSub @onChange, -> target.refresh()
    @xs
  at: (i) ->
    recorder.sub (target) => rx.autoSub @onChange, ([index, removed, added]) ->
      target.refresh() if index == i
    @xs[i]
  length: ->
    recorder.sub (target) => rx.autoSub @onChange, ([index, removed, added]) ->
      target.refresh() if removed.length != added.length
    @xs.length
  map: (f) ->
    ys = new MappedDepArray()
    rx.autoSub @onChange, ([index, removed, added]) ->
      ys.realSplice(index, removed.length, added.map(f))
    ys
  indexed: ->
    if not @indexed_?
      @indexed_ = new IndexedDepArray()
      rx.autoSub @onChange, ([index, removed, added]) =>
        @indexed_.realSplice(index, removed.length, added)
    @indexed_
  concat: (that) -> rx.concat(this, that)
  realSplice: (index, count, additions) ->
    removed = @xs.splice.apply(@xs, [index, count].concat(additions))
    @onChange.pub([index, removed, additions])
  _update: (val, diff = @diff) ->
    old = @xs
    fullSplice = [0, old.length, val]
    x = null
    splices =
      if diff?
        permToSplices(old.length, val, diff(old, val)) ? [fullSplice]
      else
        [fullSplice]
    #console.log(old, val, splices, fullSplice, diff, @diff)
    for splice in splices
      [index, count, additions] = splice
      @realSplice(index, count, additions)

SrcArray = class rx.SrcArray extends ObsArray
  spliceArray: (index, count, additions) -> recorder.mutating =>
    @realSplice(index, count, additions)
  splice: (index, count, additions...) -> @spliceArray(index, count, additions)
  insert: (x, index) -> @splice(index, 0, x)
  remove: (x) ->
    i = _(@raw()).indexOf(x)
    @removeAt(i) if i >= 0
  removeAt: (index) -> @splice(index, 1)
  push: (x) -> @splice(@length(), 0, x)
  put: (i, x) -> @splice(i, 1, x)
  replace: (xs) -> @spliceArray(0, @length(), xs)
  update: (xs) -> recorder.mutating => @_update(xs)

MappedDepArray = class rx.MappedDepArray extends ObsArray
IndexedDepArray = class rx.IndexedDepArray extends ObsArray
  constructor: (xs = [], diff) ->
    super(xs, diff)
    @is = (rx.cell(i) for x,i in @xs)
    @onChange = new Ev(=> [[0, [], _.zip(@xs, @is)]]) # [index, removed, added]
  map: (f) ->
    ys = new IndexedMappedDepArray()
    rx.autoSub @onChange, ([index, removed, added]) ->
      ys.realSplice(index, removed.length, (f(a,i) for [a,i] in added))
    ys
  realSplice: (index, count, additions) ->
    # rx.transaction =>
    removed = @xs.splice(index, count, additions...)
    for i, offset in @is[index + count...]
      i.set(index + additions.length + offset)
    newIs = (rx.cell(index + i) for i in [0...additions.length])
    @is.splice(index, count, newIs...)
    @onChange.pub([index, removed, _.zip(additions, newIs)])
IndexedMappedDepArray = class rx.IndexedMappedDepArray extends IndexedDepArray

DepArray = class rx.DepArray extends ObsArray
  constructor: (@f, diff) ->
    super([], diff)
    rx.autoSub (bind => @f()).onSet, ([old, val]) => @_update(val)

IndexedArray = class rx.IndexedArray extends DepArray
  constructor: (@xs) ->
  map: (f) ->
    ys = new MappedDepArray()
    rx.autoSub @xs.onChange, ([index, removed, added]) ->
      ys.realSplice(index, removed.length, added.map(f))
    ys

rx.concat = (xss...) ->
  ys = new MappedDepArray()
  repLens = (0 for xs in xss)
  xss.map (xs, i) ->
    rx.autoSub xs.onChange, ([index, removed, added]) ->
      xsOffset = sum(repLens[...i])
      repLens[i] += added.length - removed.length
      ys.realSplice(xsOffset + index, removed.length, added)
  ys

FakeSrcCell = class rx.FakeSrcCell extends SrcCell
  constructor: (@_getter, @_setter) ->
  get: -> @_getter()
  set: (x) -> @_setter(x)

FakeObsCell = class rx.FakeObsCell extends ObsCell
  constructor: (@_getter) ->
  get: -> @_getter()

SrcMapEntryCell = class rx.MapEntryCell extends FakeSrcCell
  constructor: (@_map, @_key) ->
  get: -> @_map.get(@_key)
  set: (x) -> @_map.put(@_key, x)

ObsMapEntryCell = class rx.ObsMapEntryCell extends FakeObsCell
  constructor: (@_map, @_key) ->
  get: -> @_map.get(@_key)

ObsMap = class rx.ObsMap
  constructor: (@x = {}) ->
    @onAdd = new Ev(=> ([k,v] for k,v of x)) # [key, new]
    @onRemove = new Ev() # [key, old]
    @onChange = new Ev() # [key, old, new]
  get: (key) ->
    recorder.sub (target) => rx.autoSub @onAdd, ([subkey, val]) ->
      target.refresh() if key == subkey
    recorder.sub (target) => rx.autoSub @onChange, ([subkey, old, val]) ->
      target.refresh() if key == subkey
    recorder.sub (target) => rx.autoSub @onRemove, ([subkey, old]) ->
      target.refresh() if key == subkey
    @x[key]
  all: ->
    recorder.sub (target) => rx.autoSub @onAdd, -> target.refresh()
    recorder.sub (target) => rx.autoSub @onChange, -> target.refresh()
    recorder.sub (target) => rx.autoSub @onRemove, -> target.refresh()
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
  cell: (key) ->
    new ObsMapEntryCell(@, key)

SrcMap = class rx.SrcMap extends ObsMap
  put: (key, val) ->
    recorder.mutating => @realPut(key, val)
  remove: (key) ->
    recorder.mutating => @realRemove(key)
  cell: (key) ->
    new SrcMapEntryCell(@, key)

DepMap = class rx.DepMap extends ObsMap
  constructor: (@f) ->
    super()
    rx.autoSub new DepCell(@f).onSet, ([old, val]) ->
      for k,v of old
        if k not of val
          @realRemove(k)
      for k,v of val
        if @x[k] != v
          @realPut(k,v)

#
# Converting POJO attributes to reactive ones.
#

rx.liftSpec = (obj) ->
  _.object(
    for name in Object.getOwnPropertyNames(obj)
      val = obj[name]
      continue if val? and (val instanceof rx.ObsMap or val instanceof rx.ObsCell or val instanceof rx.ObsArray)
      type =
        if _.isFunction(val) then null
        else if _.isArray(val) then 'array'
        else 'cell'
      [name, {type, val}]
  )

rx.lift = (x, fieldspec = rx.liftSpec(x)) ->
  for name, spec of fieldspec
    x[name] = switch spec.type
      when 'cell'
        rx.cell(x[name])
      when 'array'
        rx.array(x[name])
      when 'map'
        rx.map(x[name])
      else
        x[name]
  x

rx.unlift = (x) ->
  _.object(
    for k,v of x
      [
        k
        if v instanceof rx.ObsCell
          v.get()
        else if v instanceof rx.ObsArray
          v.all()
        else
          v
      ]
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
            else throw new Error("Unknown observable type: #{type}")
          [name, desc]
    )

rx.autoReactify = (obj) ->
  rx.reactify obj, _.object(
    for name in Object.getOwnPropertyNames(obj)
      val = obj[name]
      continue if val instanceof ObsMap or val instanceof ObsCell or val instanceof ObsArray
      type =
        if _.isFunction(val) then null
        else if _.isArray(val) then 'array'
        else 'cell'
      [name, {type, val}]
  )

_.extend(rx, {
  cell: (x) -> new SrcCell(x)
  array: (xs, diff) -> new SrcArray(xs, diff)
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

flatten = (xss) ->
  xs = _.flatten(xss)
  rx.cellToArray bind -> _.flatten(xss)

rx.cellToArray = (cell, diff) ->
  new DepArray((-> cell.get()), diff)

# O(n) using hash key
rx.basicDiff = (key = rx.smartUidify) -> (oldXs, newXs) ->
  oldKeys = mkMap([key(x), i] for x,i in oldXs)
  ((oldKeys[key(x)] ? -1) for x in newXs)

# This is invasive; WeakMaps can't come soon enough....
rx.uidify = (x) ->
  x.__rxUid ? (
    Object.defineProperty x, '__rxUid',
      enumerable: false
      value: mkuid()
  ).__rxUid

# Need a "hash" that distinguishes different types and distinguishes object
# UIDs from ints.
rx.smartUidify = (x) ->
  if _.isObject(x)
    rx.uidify(x)
  else
    JSON.stringify(x)

# Note: this gives up and returns null if there are reorderings or
# duplications; only handles (multiple) simple insertions and removals
# (batching them together into splices).
permToSplices = (oldLength, newXs, perm) ->
  refs = (i for i in perm when i >= 0)
  return null if _.some(refs[i + 1] - refs[i] <= 0 for i in [0...refs.length - 1])
  splices = []
  last = -1
  i = 0
  while i < perm.length
    # skip over any good consecutive runs
    while i < perm.length and perm[i] == last + 1
      last += 1
      i += 1
    # lump any additions into this splice
    splice = {index: i, count: 0, additions: []}
    while i < perm.length and perm[i] == -1
      splice.additions.push(newXs[i])
      i += 1
    # Find the step difference to find how many from old were removed/skipped;
    # if no step (perm[i] == last + 1) then count should be 0.  If we see no
    # more references to old elements, then we need oldLength to determine how
    # many remaining old elements were logically removed.
    cur = if i == perm.length then oldLength else perm[i]
    splice.count = cur - (last + 1)
    if splice.count > 0 or splice.additions.length > 0
      splices.push([splice.index, splice.count, splice.additions])
    last = cur
    i += 1
  splices

rx.transaction = (f) -> depMgr.transaction(f)

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
        throw new Error('Unknown reactive property type')

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

setDynProp = (elt, prop, val, xform = _.identity) ->
  if val instanceof ObsCell
    rx.autoSub val.onSet, ([o,n]) -> setProp(elt, prop, xform(n))
  else
    setProp(elt, prop, xform(val))

rxt.mktag = mktag = (tag) ->
  (arg1, arg2) ->
    # arguments may be:
    #   ()
    #   (attrs: Object)
    #   (contents: Contents)
    #   (attrs: Object, contents: Contents)
    # where Contents is:
    #   string | Element | RawHtml | $ | Array | ObsCell | ObsArray
    #
    # if Contents is a function it will be evaluated, and expected to
    #   return an allowable Contents instance
    [attrs, contents] =
      if not arg1? and not arg2?
        [{}, null]
      else if arg2?
        [arg1, arg2]
      else if _.isString(arg1) or arg1 instanceof Element or
          arg1 instanceof RawHtml or arg1 instanceof $ or _.isArray(arg1) or
          arg1 instanceof ObsCell or arg1 instanceof ObsArray or
          arg1 instanceof Function
        [{}, arg1]
      else
        [arg1, null]

    contents = contents.apply() if contents instanceof Function

    elt = $("<#{tag}/>")
    for name, value of _.omit(attrs, _.keys(specialAttrs))
      setDynProp(elt, name, value)
    if contents?
      toNodes = (contents) ->
        for child in contents
          if _.isString(child)
            document.createTextNode(child)
          else if child instanceof Element
            child
          else if child instanceof RawHtml
            parsed = $(child.html)
            throw new Error('RawHtml must wrap a single element') if parsed.length != 1
            parsed[0]
          else if child instanceof $
            throw new Error('jQuery object must wrap a single element') if child.length != 1
            child[0]
          else
            throw new Error("Unknown element type in array: #{child.constructor.name} (must be string, Element, RawHtml, or jQuery objects)")
      updateContents = (contents) ->
        elt.html('')
        if _.isArray(contents)
          nodes = toNodes(contents)
          elt.append(nodes)
          if false # this is super slow
            hasWidth = (node) ->
              try $(node).width()? != 0
              catch e then false
            covers = for node in nodes ? [] when hasWidth(node)
              {left, top} = $(node).offset()
              $('<div/>').appendTo($('body').first())
                .addClass('updated-element').offset({top,left})
                .width($(node).width()).height($(node).height())
            setTimeout (-> $(cover).remove() for cover in covers), 2000
        else if _.isString(contents) or contents instanceof Element or
            contents instanceof RawHtml or contents instanceof $
          updateContents([contents])
        else
          throw new Error("Unknown type for element contents: #{contents.constructor.name} (accepted types: string, Element, RawHtml, jQuery object of single element, or array of the aforementioned)")
      if contents instanceof ObsArray
        rx.autoSub contents.onChange, ([index, removed, added]) ->
          elt.contents().slice(index, index + removed.length).remove()
          toAdd = toNodes(added)
          if index == elt.contents().length
            elt.append(toAdd)
          else
            elt.contents().eq(index).before(toAdd)
      else if contents instanceof ObsCell
        # TODO: make this more efficient by checking each element to see if it
        # changed (i.e. layer a MappedDepArray over this, and make DepArrays
        # propagate the minimal change set)
        rx.autoSub contents.onSet, ([old, val]) -> updateContents(val)
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

#
# rxt utilities
#

rxt.cast = (opts, types) ->
  _.object(
    for key, value of opts
      newval = switch types[key]
        when 'array'
          if value instanceof rx.ObsArray
            value
          else if _.isArray(value)
            new rx.DepArray(-> value)
          else if value instanceof rx.ObsCell
            new rx.DepArray(-> value.get())
          else
            throw new Error('Cannot cast to array: ' + value.constructor.name)
        when 'cell'
          if value instanceof rx.ObsCell
            value
          else
            bind -> value
        else
          value
      [key, newval]
  )

rxt.cssify = (map) ->
  (
    for k,v of map when v?
      "#{_.str.dasherize(k)}: #{if _.isNumber(v) then v+'px' else v};"
  ).join(' ')

specialAttrs.style = (elt, value) ->
  setDynProp elt, 'style', value, (val) ->
    if _.isString(val) then val else rxt.cssify(val)

rxt.smushClasses = (xs) ->
  _(xs).chain().flatten().compact().value().join(' ').replace(/\s+/, ' ').trim()

specialAttrs.class = (elt, value) ->
  setDynProp elt, 'class', value, (val) ->
    if _.isString(val) then val else rxt.smushClasses(val)
