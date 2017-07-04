rxFactory = (_, $) ->
  rx = {}
  nextUid = 0
  mkuid = -> nextUid += 1

  union = (first, second) -> new Set [first..., second...]
  intersection = (first, second) -> new Set Array.from(first).filter (item) -> second.has item
  difference = (first, second) -> new Set Array.from(first).filter (item) -> not second.has item

  popKey = (x, k) ->
    if k not of x
      throw new Error('object has no key ' + k)
    v = x[k]
    delete x[k]
    v

  mapPop = (x, k) ->
    v = x.get k
    x.delete k
    return v

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
      @buffering = 0
      @buffer = []
      @events = new Set()
    # called by Ev.sub to register a new subscription
    transaction: (f) ->
      @buffering += 1
      try
        res = f()
      finally
        @buffering -= 1
        if @buffering == 0
          immediateDeps = new Set _.flatten Array.from(@events).map ({downstreamCells}) -> Array.from downstreamCells
          allDeps = rx.allDownstream immediateDeps...
          allDeps.forEach (cell) -> cell._shield = true
          try
            # we need to clear the buffer now, in case rx.transaction is called as a result of one
            # the events that we're publishing, since that would cause transaction to execute again with
            # the full buffer, causing an infinite loop.
            bufferedPubs = @buffer
            @buffer = []
            @events.clear()

            bufferedPubs.map ([ev, data]) -> ev.pub data
            allDeps.forEach (c) -> c.refresh()
          finally
            allDeps.forEach (cell) -> cell._shield = false
      res

  rx._depMgr = depMgr = new DepMgr()

  Ev = class rx.Ev
    constructor: (@init, @observable) ->
      @subs = mkMap()
      @downstreamCells = new Set()
    sub: (listener) ->
      uid = mkuid()
      if @init? then listener @init()
      @subs[uid] = listener
      uid
    # callable only by the src
    pub: (data) ->
      if depMgr.buffering
        depMgr.buffer.push [@, data]
        depMgr.events.add @
      else
        for uid, listener of @subs
          listener(data)
    unsub: (uid) ->
      popKey(@subs, uid)
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

  rx.upstream = (cell) ->
    events = Array.from cell.upstreamEvents
    depCells = events.map (ev) -> ev.observable
    Array.from new Set depCells

  allDownstreamHelper = rx._allDownstreamHelper = (cells...) ->
    if cells.length
      downstream = Array.from new Set _.flatten cells.map (cell) ->
        Array.from cell.onSet.downstreamCells
      r = _.flatten [downstream, allDownstreamHelper downstream...]
      return r
    return []

  rx.allDownstream = (cells...) ->
    Array.from(new Set [cells..., allDownstreamHelper(cells...)...].reverse()).reverse()


  Recorder = class rx.Recorder
    constructor: ->
      @stack = []
      @isMutating = false
      @isIgnoring = false
      @hidingMutationWarnings = false
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

    # subscribes the current cell to an event; the cell will refresh if the event fires and condFn returns true.
    # note that we are establishing both directions of the dependency tracking here (subscribing
    # to the dependency's events as well as registering the subscription UID with the current listener)
    sub: (event, condFn=->true) ->
      if @stack.length > 0 and not @isIgnoring
        topCell = _(@stack).last()
        topCell.upstreamEvents.add event
        event.downstreamCells.add topCell
        rx.autoSub event, (evData...) ->
          if condFn evData... then topCell.refresh()

    addCleanup: (cleanup) ->
      _(@stack).last().addCleanup(cleanup) if @stack.length > 0
    # Delimit the function as one where a mutation takes place, such that if
    # within this function we refresh a bind, we don't treat that bind as a
    # nested bind (which causes all sorts of problems e.g. the cascading
    # disconnects)
    hideMutationWarnings: (f) ->
      wasHiding = @hidingMutationWarnings
      @hidingMutationWarnings = true
      try f()
      finally @hidingMutationWarnings = wasHiding

    fireMutationWarning: ->
      console.warn 'Mutation to observable detected during a bind context'
      @onMutationWarning.pub null
    mutating: (f) ->
      if @stack.length > 0 and not @hidingMutationWarnings
        @fireMutationWarning()
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

  rx.types = {'cell', 'array', 'map', 'set'}

  rx._recorder = recorder = new Recorder()

  rx.hideMutationWarnings = (f) -> recorder.hideMutationWarnings f

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
      if timeout?
        clearTimeout(timeout)
      timeout = setTimeout((=> @done(val)), ms)

  rx.snap = (f) -> recorder.ignoring(f)

  rx.onDispose = (cleanup) -> recorder.addCleanup(cleanup)

  rx.autoSub = (ev, listener) ->
    subid = ev.sub(listener)
    rx.onDispose -> ev.unsub(subid)
    subid

  rx.subOnce = (event, listener) ->
    uid = rx.autoSub event, rx.skipFirst (args...) ->
      _.defer -> listener args...
      event.unsub uid
    return uid

  ObsBase = class rx.ObsBase
    constructor: ->
      @events = []
    to: {
      cell: => rx.cell.from @
      array: => rx.array.from @
      map: => rx.map.from @
      set: => rx.set.from @
    }
    flatten: -> rx.flatten @
    subAll: (condFn=-> true) -> @events.forEach (ev) -> recorder.sub ev, condFn
    raw: -> @_base
    _mkEv: (f) ->
      ev = new Ev f, @
      @events.push ev
      ev


  ObsCell = class rx.ObsCell extends ObsBase
    constructor: (@_base) ->
      super()
      @_base = @_base ? null
      @onSet = @_mkEv => [null, @_base] # [old, new]
      @_shield = false
      downstreamCells = => @onSet.downstreamCells
      @refreshAll = =>
        if @onSet.downstreamCells.size and not @_shield
          @_shield = true
          cells = rx.allDownstream Array.from(downstreamCells())...
          cells.forEach (c) -> c._shield = true
          try cells.forEach (c) -> c.refresh()
          finally
            cells.forEach (c) -> c._shield = false
            @_shield = false
      @refreshSub = rx.autoSub @onSet, @refreshAll

    all: ->
      @subAll => not @_shield
      @_base
    get: -> @all()
    readonly: -> new DepCell => @all()

  SrcCell = class rx.SrcCell extends ObsCell
    set: (x) -> recorder.mutating => if @_base != x
      old = @_base
      @_base = x
      @onSet.pub([old, x])
      old

  DepCell = class rx.DepCell extends ObsCell
    constructor: (@body, init) ->
      super(init ? null)
      @refreshing = false
      @nestedBinds = []
      @cleanups = []
      @upstreamEvents = new Set()
    refresh: ->
      if not @refreshing
        old = @_base
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
        realDone = (@_base) =>
          @onSet.pub [old, @_base]
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
      @upstreamEvents.forEach (ev) => ev.downstreamCells.delete @
      @upstreamEvents.clear()
    # called by recorder
    addNestedBind: (nestedBind) ->
      @nestedBinds.push(nestedBind)
    # called by recorder
    addCleanup: (cleanup) ->
      @cleanups.push(cleanup)

  ObsArray = class rx.ObsArray extends ObsBase
    constructor: (@_cells = [], @diff = rx.basicDiff()) ->
      super()
      @onChange = @_mkEv => [0, [], @_cells.map (c) -> c.raw()] # [index, removed, added]
      @onChangeCells = @_mkEv => [0, [], @_cells] # [index, removed, added]
      @_indexed = null
    all: ->
      recorder.sub @onChange
      @_cells.map (c) -> c.get()
    raw: -> @_cells.map (c) -> c.raw()
    readonly: -> new DepArray => @all()
    rawCells: -> @_cells
    at: (i) ->
      recorder.sub @onChange, ([index, removed, added]) ->
        # if elements were inserted or removed prior to this element
        if index <= i and removed.length != added.length then true
        # if this element is one of the elements changed
        else if removed.length == added.length and i <= index + removed.length then true
        else false
      @_cells[i]?.get()
    length: ->
      recorder.sub @onChangeCells, ([index, removed, added]) -> removed.length != added.length
      @_cells.length
    size: -> @length()
    map: (f) ->
      ys = new MappedDepArray()
      rx.autoSub @onChangeCells, ([index, removed, added]) =>
        for cell in ys._cells[index...index + removed.length]
          cell.disconnect()
        newCells =
          added.map (item) ->
            cell = bind -> f(item.get())
        ys.realSpliceCells(index, removed.length, newCells)
      ys
    transform: (f, diff) -> new DepArray (=> f @all()), diff
    filter: (f) -> @transform (arr) -> arr.filter f
    slice: (x, y) -> @transform (arr) -> arr.slice(x, y)
    reduce: (f, init) ->  @all().reduce f, init ? @at 0
    reduceRight: (f, init) ->  @all().reduceRight f, init ? @at 0
    every: (f) ->  @all().every f
    some: (f) ->  @all().some f
    indexOf: (val, from=0) -> @all().indexOf val, from
    lastIndexOf: (val, from) ->
      from ?= @length() - 1
      @all().lastIndexOf val, from
    join: (separator=',') ->  @all().join separator
    first: -> @at 0
    last: -> @at(@length() - 1)
    indexed: ->
      if not @_indexed?
        @_indexed = new IndexedDepArray()
        rx.autoSub @onChangeCells, ([index, removed, added]) =>
          @_indexed.realSpliceCells(index, removed.length, added)
      @_indexed
    concat: (those...) -> rx.concat(this, those...)
    realSpliceCells: (index, count, additions) ->
      removed = @_cells.splice.apply(@_cells, [index, count].concat(additions))
      removedElems = rx.snap -> (x2.get() for x2 in removed)
      addedElems = rx.snap -> (x3.get() for x3 in additions)
      rx.transaction =>
        @onChangeCells.pub([index, removed, additions])
        @onChange.pub([index, removedElems, addedElems])
    realSplice: (index, count, additions) ->
      @realSpliceCells(index, count, additions.map(rx.cell))
    _update: (val, diff = @diff) ->
      old = rx.snap => (x.get() for x in @_cells)
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
    removeAll: (x) -> rx.transaction =>
      i = _(rx.snap => @all()).indexOf x
      while i >= 0
        @removeAt i
        i = _(rx.snap => @all()).indexOf x
    removeAt: (index) ->
      val = rx.snap => @at index
      @splice(index, 1)
      return val
    push: (x) -> @splice(rx.snap(=> @length()), 0, x)
    pop: () -> @removeAt rx.snap => @length() - 1
    put: (i, x) -> @splice(i, 1, x)
    replace: (xs) -> @spliceArray(0, rx.snap(=> @length()), xs)
    unshift: (x) -> @insert x, 0
    shift: -> @removeAt 0
    # TODO: How is this different from replace? we should use one or the other.
    update: (xs) -> recorder.mutating => @_update(xs)
    move: (src, dest) -> rx.transaction =>
      # moves element at src to index before dest
      if src == dest then return

      len = rx.snap(=> @length())

      if src < 0 or src > len - 1
        throw "Source #{src} is outside of bounds of array of length #{len}"
      if dest < 0 or dest > len
        throw "Destination #{dest} is outside of bounds of array of length #{len}"

      val = rx.snap => @all()[src]

      if src > dest
        @removeAt src
        @insert val, dest
      else
        @insert val, dest
        @removeAt src

      return  # removeAt returns, but insert doesn't, so let's avoid inconsistency
    swap: (i1, i2) -> rx.transaction =>
      len = rx.snap(=> @length())
      if i1 < 0 or i1 > len - 1
        throw "i1 #{i1} is outside of bounds of array of length #{len}"
      if i2 < 0 or i2 > len - 1
        throw "i2 #{i2} is outside of bounds of array of length #{len}"

      first = Math.min i1, i2
      second = Math.max i1, i2

      @move first, second
      @move second, first

    reverse: ->
      # Javascript's Array.reverse both reverses the Array and returns its new value
      @update rx.snap => @all().reverse()
      return rx.snap => @all()

  MappedDepArray = class rx.MappedDepArray extends ObsArray
    constructor: -> super()
  IndexedDepArray = class rx.IndexedDepArray extends ObsArray
    constructor: (xs = [], diff) ->
      super(xs, diff)
      @is = (rx.cell(i) for x,i in @_cells)
      @onChangeCells = @_mkEv => [0, [], _.zip(@_cells, @is)] # [index, removed, added]
      @onChange = @_mkEv => [0, [], _.zip(@is, rx.snap => @all())]
    # TODO duplicate code with ObsArray
    map: (f) ->
      ys = new MappedDepArray()
      rx.autoSub @onChangeCells, ([index, removed, added]) =>
        for cell in ys._cells[index...index + removed.length]
          cell.disconnect()
        newCells =
          for [item, icell] in added
            cell = bind -> f(item.get(), icell)
        ys.realSpliceCells(index, removed.length, newCells)
      ys
    realSpliceCells: (index, count, additions) ->
      removed = @_cells.splice.apply(@_cells, [index, count].concat(additions))
      removedElems = rx.snap -> (x2.get() for x2 in removed)

      for i, offset in @is[index + count...]
        i.set(index + additions.length + offset)
      newIs = (rx.cell(index + i) for i in [0...additions.length])
      @is.splice(index, count, newIs...)

      addedElems = rx.snap -> (x3.get() for x3 in additions)
      rx.transaction =>
        @onChangeCells.pub([index, removed, _.zip(additions, newIs)])
        @onChange.pub([index, removedElems, _.zip(addedElems, newIs)])
  IndexedMappedDepArray = class rx.IndexedMappedDepArray extends IndexedDepArray

  DepArray = class rx.DepArray extends ObsArray
    constructor: (@f, diff) ->
      super([], diff)
      rx.autoSub (bind => Array.from @f()).onSet, ([old, val]) => @_update(val)

  IndexedArray = class rx.IndexedArray extends DepArray
    constructor: (@_cells) ->
    map: (f) ->
      ys = new MappedDepArray()
      rx.autoSub @_cells.onChange, ([index, removed, added]) ->
        ys.realSplice(index, removed.length, added.map(f))
      ys

  rx.concat = (xss...) ->
    ys = new MappedDepArray()
    casted = xss.map (xs) -> rxt.cast xs, 'array'
    repLens = (0 for xs in xss)
    casted.forEach (xs, i) ->
      rx.autoSub xs.onChange, ([index, removed, added]) ->
        xsOffset = sum repLens[...i]
        repLens[i] += added.length - removed.length
        ys.realSplice(xsOffset + index, removed.length, added)
    ys

  objToJSMap = (obj) ->
    if obj instanceof Map then obj
    else if _.isArray obj then new Map obj
    else new Map _.pairs obj

  ObsMap = class rx.ObsMap extends ObsBase
    constructor: (@_base = new Map()) ->
      super()
      @_base = objToJSMap @_base
      @onAdd = @_mkEv => new Map @_base # {key: new...}
      @onRemove = @_mkEv => new Map() # {key: old...}
      @onChange = @_mkEv => new Map() # {key: [old, new]...}
    get: (key) ->
      @subAll (result) -> result.has key
      @_base.get key
    has: (key) ->
      recorder.sub @onAdd, (additions) -> additions.has key
      recorder.sub @onRemove, (removals) -> removals.has key
      @_base.has key
    all: ->
      @subAll()
      new Map @_base
    readonly: -> new DepMap => @all()
    size: ->
      recorder.sub @onRemove
      recorder.sub @onAdd
      @_base.size
    realPut: (key, val) ->
      if @_base.has key
        old = @_base.get key
        if old != val
          @_base.set key, val
          @onChange.pub new Map [[key, [old, val]]]
        return old
      else
        @_base.set key, val
        @onAdd.pub new Map [[key, val]]
        undefined
    realRemove: (key) ->
      val = mapPop @_base, key
      @onRemove.pub new Map [[key, val]]
      val
    _update: (other) ->
      otherMap = objToJSMap other
      ret = new Map @_base
      removals = do =>
        _.chain Array.from @_base.keys()
         .difference Array.from otherMap.keys()
         .map (k) => [k, mapPop @_base, k]
         .value()

      additions = do =>
        _.chain Array.from otherMap.keys()
         .difference Array.from @_base.keys()
         .map (k) =>
           val = otherMap.get k
           @_base.set k, val
           return [k, val]
         .value()

      changes = do =>
        _.chain Array.from otherMap
         .filter ([k, val]) => @_base.has(k) and @_base.get(k) != val
         .map ([k, val]) =>
           old = @_base.get k
           @_base.set k, val
           return [k, [old, val]]
         .value()

      rx.transaction =>
        if removals.length then @onRemove.pub new Map removals
        if additions.length then @onAdd.pub new Map additions
        if changes.length then @onChange.pub new Map changes

      return ret

  SrcMap = class rx.SrcMap extends ObsMap
    put: (key, val) -> recorder.mutating => @realPut key, val
    set: (key, val) -> @put key, val
    delete: (key) -> recorder.mutating =>
      val = undefined
      if @_base.has key
        val = @realRemove key
        @onRemove.pub new Map [[key, val]]
      val
    remove: (key) -> @delete key
    clear: -> recorder.mutating =>
      removals = new Map @_base
      @_base.clear()
      if removals.size then @onRemove.pub removals
      removals
    update: (x) -> recorder.mutating => @_update x

  DepMap = class rx.DepMap extends ObsMap
    constructor: (@f) ->
      super()
      c = bind @f
      rx.autoSub c.onSet, ([old, val]) => @_update val

  #
  # Converting POJO attributes to reactive ones.
  #

  objToJSSet = (obj) -> if obj instanceof Set then obj else new Set obj
  _castOther = (other) ->
    if other instanceof Set then other
    else if other instanceof ObsSet then other = other.all()

    if other instanceof ObsArray then other = other.all()
    if other instanceof ObsCell then other = other.get()
    new Set other

  ObsSet = class rx.ObsSet extends ObsBase
    constructor: (@_base = new Set()) ->
      super()
      @_base = objToJSSet @_base
      @onChange = @_mkEv => [@_base, new Set()]  # additions, removals
    has: (key) ->
      @subAll ([additions, removals]) -> additions.has(key) or removals.has(key)
      @_base.has key
    all: ->
      @subAll()
      new Set @_base
    readonly: -> new DepSet => @all()
    values: -> @all()
    entries: -> @all()
    size: ->
      @subAll ([additions, removals]) -> additions.size != removals.size
      @_base.size
    union: (other) -> new DepSet => union @all(), _castOther other
    intersection: (other) -> new DepSet => intersection @all(), _castOther other
    difference: (other) -> new DepSet => difference @all(), _castOther other
    symmetricDifference: (other) ->
      new DepSet =>
        me = @all()
        other = _castOther other
        new Set Array.from(union(me, other)).filter (item) -> not me.has(item) or not other.has(item)
    _update: (y) -> rx.transaction =>
      old_ = new Set @_base
      new_ = objToJSSet y

      additions = new Set()
      removals = new Set()

      # JS sets don't come with subtraction :(
      old_.forEach (item) -> if not new_.has item then removals.add item
      new_.forEach (item) -> if not old_.has item then additions.add item

      old_.forEach (item) => @_base.delete item
      new_.forEach (item) => @_base.add item

      @onChange.pub [
        additions
        removals
      ]
      old_


  SrcSet = class rx.SrcSet extends ObsSet
    add: (item) -> recorder.mutating =>
      if not @_base.has item
        @_base.add item
        @onChange.pub [
          new Set [item]
          new Set()
        ]
      item
    put: (item) -> @add item
    delete: (item) -> recorder.mutating =>
      if @_base.has item
        @_base.delete item
        @onChange.pub [
          new Set()
          new Set [item]
        ]
      item
    remove: (item) -> @delete item
    clear: -> recorder.mutating =>
      removals = new Set @_base
      if @_base.size
        @_base.clear()
        @onChange.pub [
          new Set()
          removals
        ]
      removals
    update: (y) -> recorder.mutating => @_update y

  DepSet = class rx.DepSet extends ObsSet
    constructor: (@f) ->
      super()
      c = bind @f
      rx.autoSub c.onSet, ([old, val]) => @_update val

  rx.cellToSet = (c) ->
    new rx.DepSet -> c.get()

  rx.liftSpec = (obj) ->
    _.object(
      for name in Object.getOwnPropertyNames(obj)
        val = obj[name]
        continue if val? and [rx.ObsMap, rx.ObsCell, rx.ObsArray, rx.ObsSet].some (cls) -> val instanceof cls
        type =
          if _.isFunction(val) then null
          else if _.isArray(val) then 'array'
          else if val instanceof Set then 'set'
          else if val instanceof Map then 'map'
          else 'cell'
        [name, {type, val}]
    )

  rx.lift = (x, fieldspec = rx.liftSpec x) ->
    _.mapObject fieldspec, ({type}, name) ->
      if x[name] not instanceof ObsBase and type of rx.types then return rx[type] x[name]
      return x[name]

  rx.unlift = (x) -> _.mapObject x, (v) -> if v instanceof rx.ObsBase then v.all() else v

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
                    view.all()
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

  rx.cell = (value) -> new SrcCell value
  rx.cell.from = (value) ->
    if value instanceof ObsCell then value
    else if value instanceof ObsBase then bind -> value.all()
    else bind -> value

  rx.array = (xs, diff) -> new SrcArray (xs ? []).map(rx.cell), diff
  rx.array.from = (value, diff) ->
    if value instanceof rx.ObsArray then return value
    else if _.isArray(value) then f = -> value
    else if value instanceof ObsBase then f = -> value.all()
    else throw new Error "Cannot cast #{value.constructor.name} to array!"

    return new DepArray f, diff

  rx.map = (value) -> new SrcMap value
  rx.map.from = (value) ->
    if value instanceof rx.ObsMap then value
    else if value instanceof ObsBase then new DepMap -> value.get()
    else new DepMap -> value


  rx.set = (value) -> new SrcSet value
  rx.set.from = (value) ->
    if value instanceof rx.ObsSet then value
    else if value instanceof rx.ObsBase then new DepSet -> value.all()
    else new DepSet -> value

  rx.cast = (value, type='cell') ->
    if type in [ObsCell, ObsArray, ObsMap, ObsSet]
      realType = null
      switch type
        when ObsCell then realType = 'cell'
        when ObsArray then realType = 'array'
        when ObsMap then realType = 'map'
        when ObsSet then realType = 'set'
      type = realType
    if _.isString type
      if type of rx.types then rx[type].from value
      else value
    else
      opts  = value
      types = type
      x = _.mapObject opts, (value, key) -> if types[key] then rx.cast(value, types[key]) else value
      x

  #
  # Reactive utilities
  #

  rx.flatten = (xs) -> new DepArray ->
    _.chain flattenHelper [xs]
     .flatten()
     .filter (x) -> x?
     .value()

  prepContents = (contents) ->
    if contents instanceof ObsCell or contents instanceof ObsArray or _.isArray contents
      contents = rx.flatten contents
    return contents


  flattenHelper = (x) ->
    if x instanceof ObsArray then flattenHelper x.all()
    else if x instanceof ObsSet then flattenHelper Array.from x.values()
    else if x instanceof ObsCell then flattenHelper x.get()
    else if x instanceof Set then flattenHelper Array.from x
    else if _.isArray x then x.map (x_k) -> flattenHelper x_k
    else x

  flatten = (xss) ->
    xs = _.flatten(xss)
    rx.cellToArray bind -> _.flatten(xss)

  rx.cellToArray = (cell, diff) -> new DepArray (-> cell.get()), diff
  rx.cellToMap = (cell) -> new rx.DepMap -> cell.get()
  rx.cellToSet = (c) -> new rx.DepSet -> c.get()

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
      else if not arg2? and
          _.isString(arg1) or
          _.isNumber(arg1) or
          arg1 instanceof Element or
          arg1 instanceof SVGElement or
          arg1 instanceof RawHtml or
          arg1 instanceof $ or
          _.isArray(arg1) or
          arg1 instanceof ObsCell or
          arg1 instanceof ObsArray or
          arg1 instanceof ObsSet
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
        contents = prepContents contents

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
            contents.onSet.sub(([old, val]) -> updateSVGContents(elt, val))
          else
            updateSVGContents(elt, contents)

        for key of attrs when key of specialAttrs
          specialAttrs[key](elt, attrs[key], attrs, contents)
        elt

    rxt.tags = _.object([tag, rxt.mktag(tag)] for tag in tags)
    {input} = rxt.tags

    _input = (type, opts) -> input _.extend {type}, opts
    input.color = (opts) -> _input 'color', opts
    input.date = (opts) -> _input 'date', opts
    input.datetime = (opts) -> _input 'datetime', opts
    input.datetimeLocal = (opts) -> _input 'datetime-local', opts
    input.email = (opts) -> _input 'email', opts
    input.file = (opts) -> _input 'file', opts
    input.hidden = (opts) -> _input 'hidden', opts
    input.image = (opts) -> _input 'image', opts
    input.month = (opts) -> _input 'month', opts
    input.number = (opts) -> _input 'number', opts
    input.password = (opts) -> _input 'password', opts
    input.range = (opts) -> _input 'range', opts
    input.reset = (opts) -> _input 'reset', opts
    input.search = (opts) -> _input 'search', opts
    input.submit = (opts) -> _input 'submit', opts
    input.tel = (opts) -> _input 'tel', opts
    input.text = (opts) -> _input 'text', opts
    input.time = (opts) -> _input 'time', opts
    input.url = (opts) -> _input 'url', opts
    input.week = (opts) -> _input 'week', opts

    swapChecked = ($input) ->
      ###
      Swaps $input.prop so that, whenever $input.prop("checked", ...) is called to set whether $input
      is checked, we also update the content of $input.rx("checked") with the same.
      ###
      $input._oldProp = $input.prop
      $input.prop = (args...) ->
        res = $input._oldProp(args...)
        if args.length > 1 and args[0] == "checked"
          $input.rx("checked").set $input.prop("checked")
        return res
      return $input

    input.checkbox = (opts) ->
      ###
      A checkbox with a default property `data-unchecked-value` of "false".  This is so that if you
      use $.serializeJSON() to read the value of this checkbox in a form, the value will be false
      if it is unchecked.
      ###
      swapChecked input _.extend({type: "checkbox"}, opts)

    input.radio = radio = (opts) -> swapChecked input _.extend({type: "radio"}, opts)

    rxt.svg_tags = _.object([tag, rxt.svg_mktag(tag)] for tag in svg_tags)

    rxt.rawHtml = (html) -> new RawHtml(html)
    rxt.specialChar = (code, tag='span') -> rxt.rawHtml "<#{tag}>&#{code};</#{tag}>"
    rxt.unicodeChar = (code, tag='span') -> rxt.rawHtml "<#{tag}>\\u#{code};</#{tag}>"
    rxt.importTags = (x) => _(x ? this).extend(rxt.tags)
    #
    # rxt utilities
    #

    rxt.cast = (value, type = "cell") ->
      console.warn "Warning: rx.rxt.cast is deprecated. Use rx.cast instead."
      return rx.cast value, type

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
      rx.autoSub rx.cast(value).onSet, ([o,n]) ->
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
    require 'es5-shim'
    require 'es6-shim'
    rx = factory(_, $)
    module.exports = rx
  else if root._? and root.$?
    root.rx = factory(root._, root.$)
  else
    throw "Dependencies are not met for reactive: _ and $ not found"
