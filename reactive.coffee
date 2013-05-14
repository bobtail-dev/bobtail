#
# Reactivity
#

rx = {}

class Recorder
  constructor: ->
    @stack = []
  # takes a dep cell
  start: (dep) ->
    @stack.push(dep)
  stop: ->
    @stack.pop()
  # Takes a subscriber function that adds the current cell as an invalidation
  # listener
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
  dep = rx.depCell(f)
  dep.refresh()
  dep

rx.lagBind = lagBind = (init, f) ->
  dep = rx.lagDepCell(f, init)
  dep.refresh()
  dep

class DepMgr
  constructor: ->
    @uid2src = {}
  # called by source Ev
  sub: (uid, src) ->
    @uid2src[uid] = src
  # called by destination
  unsub: (uid) ->
    @uid2src[uid].unsub(uid)
    popKey(@uid2src, uid)

depMgr = new DepMgr()

class Ev
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

class ObsCell
  constructor: (@x) ->
    @x = @x ? null
    @onSet = new Ev(=> [[null, @x]]) # [old, new]
  get: ->
    recorder.sub((target) => @onSet.sub(-> target.refresh()))
    @x

class SrcCell extends ObsCell
  set: (x) ->
    recorder.warnMutate()
    old = @x
    @x = x
    @onSet.pub([old, x])
    old

class DepCell extends ObsCell
  constructor: (@body, init, lag) ->
    super(init ? null)
    @subs = []
    @refreshing = false
    @lag = lag ? false
    @timeout = null
  refresh: ->
    realRefresh = =>
      #console.log('real refresh')
      if not @refreshing
        old = @x
        for subUid in @subs
          depMgr.unsub(subUid)
        @subs = []
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
  addSub: (subUid) ->
    @subs.push(subUid)

class ObsArray
  constructor: (@xs) ->
    @xs = @xs ? []
    @onChange = new Ev(=> [[0, [], @xs]]) # [index, removed, added]
  all: ->
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

class SrcArray extends ObsArray
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

class MappedDepArray extends ObsArray

class DepArray extends ObsArray
  constructor: (@f) ->
    super()
    new DepCell(@f).onSet.sub(([old, val]) ->
      # TODO use diff algo so shifts aren't catastrophic
      [index, index] = firstWhere(
        [0..Math.min(old.length, val.length)],
        (i) -> old[i] != val[i]
      )
      if index > -1 # if found any diffs
        count = old.length - index
        additions = val[index..]
        @realSplice(index, count, additions)
    )

class ObsMap
  constructor: (@x = {}) ->
    @onAdd = new Ev(=> ([k,v] for k,v of x)) # [key, new]
    @onRemove = new Ev() # [key, old]
    @onChange = new Ev() # [key, old, new]
  get: (key) ->
    recorder.sub((target) => @onChange.sub(([subkey, old, val]) ->
      target.refresh() if key == subkey))
    @x[key]
  all: ->
    recorder.sub((target) => @onChange.sub(-> target.refresh()))
    _.clone(@x)
  realPut: (key, val) ->
    if key in @x
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

class SrcMap extends ObsMap
  put: (key, val) ->
    recorder.warnMutate()
    @realPut(key, val)
  remove: (key) ->
    recorder.warnMutate()
    @realRemove(key)

class DepMap extends ObsMap
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

_.extend(rx, {
  cell: (x) -> new SrcCell(x)
  array: (xs) -> new SrcArray(xs)
  map: (x) -> new SrcMap(x)
  depCell: (f) -> new DepCell(f)
  lagDepCell: (f, init) -> new DepCell(f, init, true)
  depMap: (f) -> new DepMap(f)
  depArray: (f) -> new DepArray(f)
})

#
# jQuery extension
#

$.fn.rx = (prop) ->
  map = $(this).data('rx-map')
  if not map? then map = $(this).data('rx-map', mkMap())
  if prop in map then return map[prop]
  map[prop] =
    switch prop
      when 'focused'
        focused = rx.cell($(this).is(':focus'))
        $(this).focus -> focused.set(true)
        $(this).blur -> focused.set(false)
        bind -> focused.get()
      when 'val'
        val = rx.cell($(this).val())
        $(this).change -> val.set(val)
        bind -> val.get()
      when 'checked'
        checked = rx.cell($(this).is(':checked'))
        $(this).change -> checked.set($(this).is(':checked'))
        bind -> checked.get()
      else
        throw 'Unknown reactive property type'

#
# reactive template DSL
#

rxt = {}

rxt.mktag = mktag = (tag) ->
  (attrs, contents) ->
    elt = $("<#{tag}/>")
    for name, value of _.omit(attrs, 'init')
      if value instanceof ObsCell
        do (name) ->
          value.onSet.sub ([old, val]) ->
            elt.attr(name, val)
      else
        elt.attr(name, value)
    if contents?
      updateContents = (contents) ->
        elt.html('')
        if contents instanceof Array
          for child in contents
            if _.isString(child)
              child = $('<span/>').text(child)
            elt.append(child)
        else
          throw 'Unknown type for contents: ' + contents.constructor.name
      if contents instanceof ObsArray
        contents.onChange.sub(([index, removed, added]) ->
          elt.children().slice(index, index + removed.length).remove()
          toAdd = $(child.get(0) for child in added)
          if index == elt.children().length
            elt.append(toAdd)
          else
            elt.children().slice(index, index + 1).before(toAdd)
        )
      else if contents instanceof ObsCell
        # TODO: make this more efficient by checking each element to see if it
        # changed (i.e. layer a MappedDepArray over this, and make DepArrays
        # propagate the minimal change set)
        contents.onSet.sub(([old, val]) ->
          updateContents(val))
      else if contents instanceof Array
        updateContents(contents)
      else
        throw 'Unknown type for contents: ' + contents.constructor.name
    attrs.init?.call(elt)
    elt

rxt.br = mktag('br') {}, []
rxt.ul = mktag('ul')
rxt.li = mktag('li')
rxt.span = mktag('span')
rxt.anchor = mktag('a')
rxt.div = mktag('div')
rxt.input = mktag('input')
rxt.select = mktag('select')
rxt.select = (attr,contents) -> mktag('select')(attr,contents)
rxt.option = mktag('option')
rxt.option = (attr,contents) -> mktag('option')(attr,contents)
rxt.label = mktag('label')
rxt.button = mktag('button')
rxt.fieldset = mktag('fieldset')
rxt.legend = mktag('legend')
rxt.h1 = mktag('h1')
rxt.h2 = mktag('h2')
rxt.h3 = mktag('h3')
rxt.h4 = mktag('h4')
rxt.h5 = mktag('h5')
rxt.h6 = mktag('h6')
rxt.h7 = mktag('h7')
