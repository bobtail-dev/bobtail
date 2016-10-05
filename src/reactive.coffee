rxFactory = (_, $) ->
  rx = {}
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
      @buffering = 0
      @buffer = []
    # called by Ev.sub to register a new subscription
    sub: (uid, src) ->
      @uid2src[uid] = src
    # called by Ev.unsub to unregister a subscription
    unsub: (uid) ->
      popKey(@uid2src, uid)
    # transactions
    transaction: (f) ->
      @buffering += 1
      try
        res = f()
      finally
        @buffering -= 1
        if @buffering == 0
          b() for b in @buffer
          @buffer = []
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

  rx.promiseBind = promiseBind = (init, f) ->
    asyncBind init, -> @record(f).done (res) => @done(res)

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
        recorded = false
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
    constructor: (@cells = [], @diff = rx.basicDiff()) ->
      @onChange = new Ev(=> [[0, [], rx.snap => (x0.get() for x0 in @cells)]]) # [index, removed, added]
      @onChangeCells = new Ev(=> [[0, [], @cells]]) # [index, removed, added]
      @indexed_ = null
    all: ->
      recorder.sub (target) => rx.autoSub @onChange, -> target.refresh()
      (x1.get() for x1 in @cells)
    raw: -> @all()
    rawCells: -> @cells
    at: (i) ->
      recorder.sub (target) => rx.autoSub @onChange, ([index, removed, added]) ->
        # XXX FIXME
        target.refresh() if index == i
      @cells[i].get()
    length: ->
      recorder.sub (target) => rx.autoSub @onChangeCells, ([index, removed, added]) ->
        target.refresh() if removed.length != added.length
      @cells.length
    map: (f) ->
      ys = new MappedDepArray()
      rx.autoSub @onChangeCells, ([index, removed, added]) =>
        for cell in ys.cells[index...index + removed.length]
          cell.disconnect()
        newCells =
          added.map (item) ->
            cell = bind -> f(item.get())
        ys.realSpliceCells(index, removed.length, newCells)
      ys
    indexed: ->
      if not @indexed_?
        @indexed_ = new IndexedDepArray()
        rx.autoSub @onChangeCells, ([index, removed, added]) =>
          @indexed_.realSpliceCells(index, removed.length, added)
      @indexed_
    concat: (that) -> rx.concat(this, that)
    realSpliceCells: (index, count, additions) ->
      removed = @cells.splice.apply(@cells, [index, count].concat(additions))
      removedElems = rx.snap -> (x2.get() for x2 in removed)
      addedElems = rx.snap -> (x3.get() for x3 in additions)
      @onChangeCells.pub([index, removed, additions])
      @onChange.pub([index, removedElems, addedElems])
    realSplice: (index, count, additions) ->
      @realSpliceCells(index, count, additions.map(rx.cell))
    _update: (val, diff = @diff) ->
      old = rx.snap => (x.get() for x in @cells)
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
      @is = (rx.cell(i) for x,i in @cells)
      @onChangeCells = new Ev(=> [[0, [], _.zip(@cells, @is)]]) # [index, removed, added]
      @onChange = new Ev(=> [[0, [], _.zip((rx.snap => @all()), @is)]])
    # TODO duplicate code with ObsArray
    map: (f) ->
      ys = new MappedDepArray()
      rx.autoSub @onChangeCells, ([index, removed, added]) =>
        for cell in ys.cells[index...index + removed.length]
          cell.disconnect()
        newCells =
          for [item, icell] in added
            cell = bind -> f(item.get(), icell)
        ys.realSpliceCells(index, removed.length, newCells)
      ys
    realSpliceCells: (index, count, additions) ->
      removed = @cells.splice.apply(@cells, [index, count].concat(additions))
      removedElems = rx.snap -> (x2.get() for x2 in removed)

      for i, offset in @is[index + count...]
        i.set(index + additions.length + offset)
      newIs = (rx.cell(index + i) for i in [0...additions.length])
      @is.splice(index, count, newIs...)

      addedElems = rx.snap -> (x3.get() for x3 in additions)
      @onChangeCells.pub([index, removed, _.zip(additions, newIs)])
      @onChange.pub([index, removedElems, _.zip(addedElems, newIs)])
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
      @onAdd = new Ev(=> @x) # {key: new...}
      @onRemove = new Ev() # {key: old...}
      @onChange = new Ev() # {key: [old, new]...}
    get: (key) ->
      recorder.sub (target) => rx.autoSub @onAdd, (additions) ->
        target.refresh() if key of additions
      recorder.sub (target) => rx.autoSub @onChange, (changes) ->
        target.refresh() if key of changes
      recorder.sub (target) => rx.autoSub @onRemove, (removals) ->
        target.refresh() if key of removals
      @x[key]
    has: (key) ->
      @x[key]?
    all: ->
      recorder.sub (target) => rx.autoSub @onAdd, -> target.refresh()
      recorder.sub (target) => rx.autoSub @onChange, -> target.refresh()
      recorder.sub (target) => rx.autoSub @onRemove, -> target.refresh()
      _.clone(@x)
    realPut: (key, val) ->
      if key of @x
        old = @x[key]
        @x[key] = val
        @onChange.pub _.object [[key, [old, val]]]
        old
      else
        @x[key] = val
        @onAdd.pub _.object [[key, val]]
        undefined
    realRemove: (key) ->
      val = popKey(@x, key)
      @onRemove.pub _.object [[key, val]]
      val
    cell: (key) ->
      new ObsMapEntryCell(@, key)
    _update: (other) ->
      removals = (
        _.chain @x
         .keys()
         .difference _.keys other
         .map (k) => [k, popKey(@x, k)]
         .object()
         .value()
      )
      additions = (
        _.chain other
         .keys()
         .difference _.keys @x
         .map (k) =>
           val = other[k]
           @x[k] = val
           return [k, val]
         .object()
         .value()
      )
      changes = (
        _.chain other
         .pairs()
         .filter ([k, val]) => k of @x and @x[k] != val
         .map ([k, val]) =>
           old = @x[k]
           @x[k] = val
           return [k, [old, val]]
         .object()
         .value()
      )

      if _.keys(removals).length then @onRemove.pub removals
      if _.keys(additions).length then @onAdd.pub additions
      if _.keys(changes).length then @onChange.pub changes

  SrcMap = class rx.SrcMap extends ObsMap
    put: (key, val) ->
      recorder.mutating => @realPut(key, val)
    remove: (key) ->
      recorder.mutating => @realRemove(key)
    cell: (key) ->
      new SrcMapEntryCell(@, key)
    update: (x) -> recorder.mutating => @_update(x)

  DepMap = class rx.DepMap extends ObsMap
    constructor: (@f) ->
      super()
      c = new DepCell(@f)
      c.refresh()
      rx.autoSub c.onSet, ([old, val]) => @_update val

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
      if not _.some(x[name] instanceof c for c in [ObsCell, ObsArray, ObsMap])
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
    array: (xs, diff) -> new SrcArray((xs ? []).map(rx.cell), diff)
    map: (x) -> new SrcMap(x)
  })

  #
  # Reactive utilities
  #

  rx.flatten = (xs) -> rx.cellToArray bind ->
    xsArray = rxt.cast(xs, 'array')
    if not xsArray.length() then return []
    _.chain xsArray.all()
     .map flattenHelper
     .flatten()
     .filter (x) -> x?
     .value()

  flattenHelper = (x) ->
    if x instanceof ObsArray then flattenHelper x.raw()
    else if x instanceof ObsCell then flattenHelper x.get()
    else if _.isArray x then x.map (x_k) -> flattenHelper x_k
    else x

  flatten = (xss) ->
    xs = _.flatten(xss)
    rx.cellToArray bind -> _.flatten(xss)

  rx.cellToArray = (cell, diff) ->
    new DepArray((-> cell.get()), diff)

  rx.cellToMap = (cell) ->
    new rx.DepMap -> @done @record -> cell.get()

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
    if not newXs.length
      return null # just do a full splice if we're emptying the array
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

  if $?
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

    rxt = {}

    rxt.events = {}
    rxt.events.enabled = false
    rxt.events.onElementChildrenChanged = new Ev()
    rxt.events.onElementAttrsChanged = new Ev()

    RawHtml = class rxt.RawHtml
      constructor: (@html) ->

    # jQuery events are special attrs, along with `init`

    events = ["blur", "change", "click", "dblclick", "error", "focus", "focusin",
      "focusout", "hover", "keydown", "keypress", "keyup", "load", "mousedown",
      "mouseenter", "mouseleave", "mousemove", "mouseout", "mouseover", "mouseup",
      "ready", "resize", "scroll", "select", "submit", "toggle", "unload"]
      
    svg_events = ["click"]

    specialAttrs = rxt.specialAttrs = {
      init: (elt, fn) -> fn.call(elt)
    }

    for ev in events
      do (ev) ->
        specialAttrs[ev] = (elt, fn) ->
          if elt instanceof SVGElement and ev in svg_events
            elt.addEventListener ev, fn
          else 
            elt[ev]((e) -> fn.call(elt, e))

    # attr vs prop:
    # http://blog.jquery.com/2011/05/10/jquery-1-6-1-rc-1-released/
    # http://api.jquery.com/prop/

    props = ['async', 'autofocus', 'checked', 'location', 'multiple', 'readOnly',
      'selected', 'selectedIndex', 'tagName', 'nodeName', 'nodeType',
      'ownerDocument', 'defaultChecked', 'defaultSelected']
    propSet = _.object([prop, null] for prop in props)

    setProp = (elt, prop, val) ->
      if elt instanceof SVGElement
        elt.setAttribute prop, val
      else if prop == 'value'
        elt.val(val)
      else if prop of propSet
        elt.prop(prop, val)
      else
        elt.attr(prop, val)

    setDynProp = (elt, prop, val, xform = _.identity) ->
      if val instanceof ObsCell
        rx.autoSub val.onSet, ([o,n]) ->
          setProp(elt, prop, xform(n))
          if rxt.events.enabled
            rxt.events.onElementAttrsChanged.pub {$element: elt, attr: prop}
      else
        setProp(elt, prop, xform(val))

    mkAtts = (attstr) ->
      do(atts = {}) ->
        id = attstr.match /[#](\w+)/
        atts.id = id[1] if id
        classes = attstr.match(/\.\w+/g)
        if classes
          atts.class = (cls.replace(/^\./, '') for cls in classes).join(' ')
        atts

    # arguments to a tag may be:
    #   ()
    #   (attrs: Object)
    #   (contents: Contents)
    #   (attrs: Object, contents: Contents)
    # where Contents is:
    #   string | number | Element | RawHtml | $ | Array | ObsCell | ObsArray
    normalizeTagArgs = (arg1, arg2) ->
      if not arg1? and not arg2?
        [{}, null]
      else if arg1 instanceof Object and arg2?
        [arg1, arg2]
      else if _.isString(arg1) and arg2?
        [mkAtts(arg1), arg2]
      else if not arg2? and
          _.isString(arg1) or
          _.isNumber(arg1) or
          arg1 instanceof Element or
          arg1 instanceof SVGElement or
          arg1 instanceof RawHtml or
          arg1 instanceof $ or
          _.isArray(arg1) or
          arg1 instanceof ObsCell or
          arg1 instanceof ObsArray
        [{}, arg1]
      else
        [arg1, null]

    toNodes = (contents) ->
      for child in contents
        if child?
          if _.isString(child) or _.isNumber(child)
            document.createTextNode(child)
          else if child instanceof Element or child instanceof SVGElement
            child
          else if child instanceof RawHtml
            parsed = $(child.html)
            throw new Error('RawHtml must wrap a single element') if parsed.length != 1
            parsed[0]
          else if child instanceof $
            throw new Error('jQuery object must wrap a single element') if child.length != 1
            child[0]
          else
            throw new Error("Unknown element type in array: #{child.constructor.name} (must be string, number, Element, RawHtml, or jQuery objects)")

    updateContents = (elt, contents) ->
      elt.html('') if elt.html
      if not contents?
        return
      else if _.isArray(contents)
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
        return nodes
      else if _.isString(contents) or _.isNumber(contents) or contents instanceof Element or
          contents instanceof SVGElement or contents instanceof RawHtml or contents instanceof $
        return updateContents(elt, [contents])
      else
        throw new Error("Unknown type for element contents: #{contents.constructor.name} (accepted types: string, number, Element, RawHtml, jQuery object of single element, or array of the aforementioned)")

    rxt.mktag = mktag = (tag) ->
      (arg1, arg2) ->
        [attrs, contents] = normalizeTagArgs(arg1, arg2)

        elt = $("<#{tag}/>")
        for name, value of _.omit(attrs, _.keys(specialAttrs))
          setDynProp(elt, name, value)
        if contents?
          if contents instanceof ObsArray
            rx.autoSub contents.indexed().onChangeCells, ([index, removed, added]) ->
              elt.contents().slice(index, index + removed.length).remove()
              toAdd = toNodes(added.map ([cell, icell]) -> rx.snap -> cell.get())
              if index == elt.contents().length
                elt.append(toAdd)
              else
                elt.contents().eq(index).before(toAdd)
              if rxt.events.enabled and (removed.length or toAdd.length)
                rxt.events.onElementChildrenChanged.pub {
                  $element: elt,
                  type: "childrenUpdated"
                  added: toAdd
                  removed: toNodes(removed.map (cell) -> rx.snap -> cell.get())
                }
              for [cell, icell] in added
                do (cell, icell) ->
                  rx.autoSub cell.onSet, rx.skipFirst ([old, val]) ->
                    ival = rx.snap -> icell.get()
                    toAdd = toNodes([val])
                    elt.contents().eq(ival).replaceWith(toAdd)
                    if rxt.events.enabled
                      rxt.events.onElementChildrenChanged.pub {
                        $element: elt, type: "childrenUpdated", updated: toAdd
                      }
          else if contents instanceof ObsCell
            # TODO: make this more efficient by checking each element to see if it
            # changed (i.e. layer a MappedDepArray over this, and make DepArrays
            # propagate the minimal change set)
            rx.autoSub contents.onSet, ([old, val]) ->
              updateContents(elt, val)
              if rxt.events.enabled
                rxt.events.onElementChildrenChanged.pub {$element: elt, type: "rerendered"}
          else
            updateContents(elt, contents)
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

    # From <https://developer.mozilla.org/en-US/docs/Web/SVG/Element>
    svg_tags = ['a', 'altglyph', 'altglyphdef', 'altglyphitem', 'animate', 
      'animatecolor', 'animatemotion', 'animatetransform', 'circle', 'clippath', 
      'color-profile', 'cursor', 'defs', 'desc', 'ellipse', 'feblend', 
      'fecolormatrix', 'fecomponenttransfer', 'fecomposite', 'feconvolvematrix', 
      'fediffuselighting', 'fedisplacementmap', 'fedistantlight', 'feflood', 
      'fefunca', 'fefuncb', 'fefuncg', 'fefuncr', 'fegaussianblur', 'feimage', 
      'femerge', 'femergenode', 'femorphology', 'feoffset', 'fepointlight', 
      'fespecularlighting', 'fespotlight', 'fetile', 'feturbulence', 'filter', 
      'font', 'font-face', 'font-face-format', 'font-face-name', 'font-face-src', 
      'font-face-uri', 'foreignobject', 'g', 'glyph', 'glyphref', 'hkern', 'image', 
      'line', 'lineargradient', 'marker', 'mask', 'metadata', 'missing-glyph', 
      'mpath', 'path', 'pattern', 'polygon', 'polyline', 'radialgradient', 'rect', 
      'script', 'set', 'stop', 'style', 'svg', 'switch', 'symbol', 'text', 
      'textpath', 'title', 'tref', 'tspan', 'use', 'view', 'vkern']
      
    updateSVGContents = (elt, contents) ->
      (elt.removeChild elt.firstChild) while elt.firstChild
      if _.isArray(contents)
        toAdd = toNodes(contents)
        (elt.appendChild node) for node in toAdd 
      else if _.isString(contents) or contents instanceof SVGElement
        updateSVGContents(elt, [contents])
      else
        console.error 'updateSVGContents', elt, contents
        throw "Must wrap contents #{contents} as array or string"
            
    rxt.svg_mktag = mktag = (tag) ->
      (arg1, arg2) ->
        [attrs, contents] = normalizeTagArgs(arg1, arg2)

        elt = document.createElementNS('http://www.w3.org/2000/svg', tag)
        for name, value of _.omit(attrs, _.keys(specialAttrs))
          setDynProp(elt, name, value)
          
        if contents?
          if contents instanceof ObsArray
            contents.onChange.sub ([index, removed, added]) -> 
              (elt.removeChild elt.childNodes[index]) for i in [0...removed.length]
              toAdd = toNodes(added)
              if index == elt.childNodes.length
                (elt.appendChild node) for node in toAdd
              else 
                (elt.childNodes[index].insertBefore node) for node in toAdd
          else if contents instanceof ObsCell
            first = contents.x[0]
#            rx.autoSub contents.onSet, ([old, val]) -> updateContents(elt, val)
            contents.onSet.sub(([old, val]) -> updateSVGContents(elt, val))      
          else
            updateSVGContents(elt, contents)          
        
        for key of attrs when key of specialAttrs
          specialAttrs[key](elt, attrs[key], attrs, contents)
        elt

    rxt.tags = _.object([tag, rxt.mktag(tag)] for tag in tags)
    rxt.svg_tags = _.object([tag, rxt.svg_mktag(tag)] for tag in svg_tags)

    rxt.rawHtml = (html) -> new RawHtml(html)
    rxt.importTags = (x) => _(x ? this).extend(rxt.tags)
    #
    # rxt utilities
    #

    rxt.cast = (value, type = "cell") ->
      if _.isString(type)
        switch type
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
      else
        opts  = value
        types = type
        _.object(
          for key, value of opts
            [key, if types[key] then rxt.cast(value, types[key]) else value]
        )

    # a little underscore-string inlining
    rxt.trim = $.trim

    rxt.dasherize = (str)->
      rxt.trim(str).replace(/([A-Z])/g, '-$1').replace(/[-_\s]+/g, '-').toLowerCase()

    rxt.cssify = (map) ->
      console.warn 'cssify is deprecated; set the `style` property directly to a JSON object.'
      (
        for k,v of map when v?
          "#{rxt.dasherize(k)}: #{if _.isNumber(v) then v+'px' else v};"
      ).join(' ')

    specialAttrs.style = (elt, value) ->
      isCell = value instanceof ObsCell
      rx.autoSub rxt.cast(value).onSet, ([o,n]) ->
        if not n? or _.isString(n)
          setProp(elt, 'style', n)
        else
          elt.removeAttr('style').css(n)
        if isCell and rxt.events.enabled
          rxt.events.onElementAttrsChanged.pub {$element: elt, attr: "style"}

    rxt.smushClasses = (xs) ->
      _(xs).chain().flatten().compact().value().join(' ').replace(/\s+/, ' ').trim()

    specialAttrs.class = (elt, value) ->
      setDynProp elt, 'class', value, (val) ->
        if _.isString(val) then val else rxt.smushClasses(val)

  rx.rxt = rxt
  rx
# end rxFactory definition

do(root = this, factory = rxFactory) ->
  deps = ['underscore']
  if is_browser = typeof(window) != 'undefined'
    deps.push 'jquery'

  if define?.amd?
    define deps, factory
  else if module?.exports?
    $ = if is_browser then require('jquery')
    _ = require 'underscore'
    rx = factory(_, $)
    module.exports = rx
  else if root._? and root.$?
    root.rx = factory(root._, root.$)
  else
    throw "Dependencies are not met for reactive: _ and $ not found"
