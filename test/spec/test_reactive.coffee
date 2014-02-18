bind = rx.bind
{div, ul, li, button, header} = rxt.tags
outerHtml = ($x) -> $x.clone().wrap('<p>').parent().html()

describe 'source cell', ->
  src = null
  beforeEach -> src = rx.cell()
  it 'initially contains null', ->
    expect(src.get()).toBe(null)
  it 'has get value that is same as last set value', ->
    src.set(1)
    expect(src.get()).toBe(1)
  it 'should not nest (and thus disconnect) binds refreshed from inside a mutation', ->
    x = rx.cell()
    xx = bind -> x.get()
    y = bind -> x.set(src.get())
    for i in [1..3]
      src.set(i)
      expect(xx.get()).toBe(i)

describe 'dependent cell', ->
  dep = src = null
  beforeEach ->
    src = rx.cell()
    dep = rx.bind -> src.get()
  it 'always reflects the dependency', ->
    expect(src.get()).toBe(dep.get())
    src.set(0)
    expect(src.get()).toBe(dep.get())
    expect(src.get()).toBe(0)
    src.set(1)
    expect(src.get()).toBe(dep.get())
    expect(src.get()).toBe(1)
  it 'cannot be set', ->
    expect(-> dep.set(0)).toThrow()

describe 'tag', ->
  size = elt = null
  beforeEach ->
    {ul, li, button, header} = rxt.tags
    size = rx.cell(10)
    elt = header {
      class: 'my-class'
      style: bind -> "font-size: #{size.get()}px"
      id: 'my-elt'
      click: ->
      init: -> @data('foo', 'bar')
    }, bind -> [
      'hello world'
      button ['click me']
    ]
  it 'should have the right tag', ->
    expect(elt.is('header')).toBe(true)
  it 'should have the set attributes', ->
    expect(elt.prop('class')).toBe('my-class')
    expect(elt.attr('style')).toBe('font-size: 10px')
    expect(elt.prop('id')).toBe('my-elt')
    expect(elt.hasClass('my-class')).toBe(true)
    expect(elt.css('font-size')).toBe('10px')
    expect(elt.data('foo')).toBe('bar')
  it 'should update attrs in response to size changes', ->
    size.set(9)
    expect(elt.attr('style')).toBe('font-size: 9px')
    expect(elt.css('font-size')).toBe('9px')
  it 'should have the given child contents', ->
    cont = elt.contents()
    expect(cont.length).toBe(2)
    expect(cont[0]).toEqual(jasmine.any(Text))
    expect(cont[0].textContent).toBe('hello world')
    expect(cont.last().is('button')).toBe(true)
    expect(cont.last().text()).toBe('click me')
  it 'should not have special attrs set', ->
    expect(elt.attr('init')).toBe(undefined)
    expect(elt.attr('click')).toBe(undefined)

  describe 'attribute id and class parsing', ->
    it 'should be creatable with a shortcut syntax for attrs object', ->
      elt = div '#zip.zap.zop', 'text'
      expect(elt.prop('id')).toBe('zip')
      expect(elt.hasClass('zap')).toBe(true)
      expect(elt.hasClass('zop')).toBe(true)

  describe 'creation of nodes', ->
    describe 'stabby proc style', ->
      it 'should be usable', ->
        testlist = div ->
          ul ['wontoo'].map (item) ->
            li item
        expect(testlist.html()).toBe('<ul><li>wontoo</li></ul>')

      it 'should allow nesting of tags', ->
        testlist = div ->
          ul ->
            li -> 'wontoo'
        expect(testlist.html()).toBe('<ul><li>wontoo</li></ul>')

      it 'should work with multiple nested nodes with array notation', ->
        testlist = div ->
          ul -> [
            li -> 'won'
            li -> 'too'
          ]
        expect(testlist.html()).toBe('<ul><li>won</li><li>too</li></ul>')

      it 'should work with multiple nested nodes with string contents', ->
        testlist = div ->
          ul -> [
            li 'won'
            li 'too'
          ]
        expect(testlist.html()).toBe('<ul><li>won</li><li>too</li></ul>')

      it 'should work with multiple nested nodes with implicit array semantics' #, ->
        # testlist = div ->
        #   ul ->
        #     li -> 'won'
        #     li -> 'too'
        # expect(testlist.html()).toBe('<ul><li>won</li><li>too</li></ul>')


      it 'should allow attr hash', ->
        testlist = div ->
          ul = ul {class:'foo'}, ->
            li -> 'wontoo'
        expect(ul.hasClass('foo')).toBe(true)

      it 'should allow attr string', ->
        testlist = div ->
          ul = ul "#bar.foo", ->
            li -> 'wontoo'
        expect(ul.hasClass('foo')).toBe(true)
        expect(ul.prop('id')).toBe('bar')

      it 'should still work with rx.binds', ->
        c = rx.cell('juan')
        testlist = div ->
          ul = ul ->
            li -> rx.bind -> c.get()
        expect(testlist.html()).toBe('<ul><li>juan</li></ul>')
        c.set('juantu')
        expect(testlist.html()).toBe('<ul><li>juantu</li></ul>')


describe 'rxt of observable array', ->
  xs = elt = null
  beforeEach ->
    xs = rx.array([1,2,3])
    elt = rxt.tags.ul xs.map (x) ->
      if x % 2 == 0
        "plain #{x}"
      else
        rxt.tags.li "item #{x}"
  it 'should be initialized to the given contents', ->
    cont = elt.contents()
    expect(cont.length).toBe(3)
    expect(cont.eq(0).is('li')).toBe(true)
    expect(cont.eq(0).text()).toBe('item 1')
    expect(cont[1]).toEqual(jasmine.any(Text))
    expect(cont.eq(1).text()).toBe('plain 2')
    expect(cont.eq(2).is('li')).toBe(true)
    expect(cont.eq(2).text()).toBe('item 3')
  it 'should update contents in response to array changes', ->
    xs.splice(0, 3, 0, 1, 2)
    cont = elt.contents()
    expect(cont[0]).toEqual(jasmine.any(Text))
    expect(cont.eq(0).text()).toBe('plain 0')
    expect(cont.eq(1).is('li')).toBe(true)
    expect(cont.eq(1).text()).toBe('item 1')
    expect(cont[2]).toEqual(jasmine.any(Text))
    expect(cont.eq(2).text()).toBe('plain 2')

describe 'SrcArray', ->
  it 'should not remove anything if element not found', ->
    xs = rx.array(['a','b','c'])
    xs.remove('d')
    expect(xs.raw()).toEqual(['a','b','c'])
    xs.remove('b')
    expect(xs.raw()).toEqual(['a','c'])

describe 'DepArray', ->
  x = xs = ys = null
  beforeEach ->
    x = rx.cell([1,2,3])
    xs = new rx.DepArray(-> x.get())
    ys = xs.map (x) -> 2 * x
  it 'should initialize to cell array contents', ->
    expect(xs.all()).toEqual([1,2,3])
    expect(ys.all()).toEqual([2,4,6])
  it 'should update in response to cell updates', ->
    x.set([2,3,4])
    expect(xs.all()).toEqual([2,3,4])
    expect(ys.all()).toEqual([4,6,8])

describe 'ObsMap', ->
  x = cb = a = b = all = null
  beforeEach ->
    x = new rx.map({a:0})
    cb = jasmine.createSpy('cb')
    a = bind -> x.get('a')
    b = bind -> x.get('b')
    all = bind -> x.all()
  it 'should fire onChange event for replaced keys', ->
    x.onChange.sub cb
    x.put('a', 1)
    expect(cb).toHaveBeenCalledWith(['a',0,1])
  it 'should fire onAdd event for new keys', ->
    x.onAdd.sub cb
    x.put('b', 2)
    expect(cb).toHaveBeenCalledWith(['b', 2])
  it 'should fire onRemove event for deleted keys', ->
    x.onRemove.sub cb
    x.remove('a')
    expect(cb).toHaveBeenCalledWith(['a', 0])
  it 'should re-evaluate .get() binds on any change', ->
    expect(a.get()).toBe(0)
    expect(b.get()).toBeUndefined()
    x.put('a', 1)
    expect(a.get()).toBe(1)
    expect(b.get()).toBeUndefined()
    x.put('b', 2)
    expect(a.get()).toBe(1)
    expect(b.get()).toBe(2)
    x.remove('a')
    expect(a.get()).toBeUndefined()
    expect(b.get()).toBe(2)
  it 'should re-evaluate .all() binds on any change', ->
    expect(all.get()).toEqual({a:0})
    x.put('a', 1)
    expect(all.get()).toEqual({a:1})
    x.put('b', 2)
    expect(all.get()).toEqual({a:1,b:2})
    x.remove('a')
    expect(all.get()).toEqual({b:2})
  it 'should yield working cells', ->
    a = x.cell('a')
    b = x.cell('b')
    aa = bind -> a.get()
    bb = bind -> b.get()
    expect(aa.get()).toBe(0)
    expect(bb.get()).toBeUndefined()
    a.set(1)
    expect(aa.get()).toBe(1)
    expect(bb.get()).toBeUndefined()
    b.set(2)
    expect(aa.get()).toBe(1)
    expect(bb.get()).toBe(2)

describe 'nested bindings', ->
  x = a = b = elt = null
  outerDisposed = innerDisposed = false
  beforeEach ->
    outerDisposed = innerDisposed = false
    x = rx.cell('')
    a =
      bind ->
        bind ->
          rx.onDispose -> innerDisposed = true
          x.get()
        rx.onDispose -> outerDisposed = true
        x.get()
    b =
      bind ->
        bind -> x.get()
        bind ->
          bind -> x.get()
          x.get()
        x.get()
  it 'should not leak memory via subscription references', ->
    expect(innerDisposed).toBe(false)
    expect(outerDisposed).toBe(false)
    nsubs0 = _.keys(x.onSet.subs).length
    x.set(' ')
    expect(innerDisposed).toBe(true)
    expect(outerDisposed).toBe(true)
    nsubs1 = _.keys(x.onSet.subs).length
    x.set('  ')
    nsubs2 = _.keys(x.onSet.subs).length
    expect(nsubs0).toBe(nsubs1)
    expect(nsubs0).toBe(nsubs2)

describe 'onDispose', ->
  it 'should not die even outside any bind context', ->
    rx.onDispose -> expect(false).toBe(true)
  it 'should not fire after context is disposed', ->
    x = rx.cell()
    y = bind ->
      counter = 0
      rx.onDispose -> expect(counter += 1).toBe(1)
      x.get()
    x.set(0)
    x.set(1)

describe 'reactify', ->
  cards = deck = null
  lastInDeckIsFlipped = lastIsFlipped = null
  operate = null
  class Card
    constructor: (isFlipped) ->
      @isFlipped = isFlipped ? false
      rx.autoReactify(@)
  class Deck
    constructor: ->
      @cards = [new Card(), new Card()]
      rx.autoReactify(@)
  beforeEach ->
    cards = rx.reactify([new Card(), new Card()])
    deck = new Deck()
    operate = (cards) ->
      card = cards[cards.length - 1]
      card.isFlipped = not card.isFlipped
    lastIsFlipped = bind -> cards[cards.length - 1].isFlipped
    lastInDeckIsFlipped = bind -> deck.cards[deck.cards.length - 1].isFlipped
  it 'should make object fields reactive', ->
    expect(lastIsFlipped.get()).toBe(false)
    expect(lastInDeckIsFlipped.get()).toBe(false)
    operate(cards)
    expect(lastIsFlipped.get()).toBe(true)
    expect(lastInDeckIsFlipped.get()).toBe(false)
    operate(deck.cards)
    expect(lastIsFlipped.get()).toBe(true)
    expect(lastInDeckIsFlipped.get()).toBe(true)
  it 'should make array fields reactive', ->
    deck.cards.push(new Card(true))
    expect(lastInDeckIsFlipped.get()).toBe(true)
  it 'should not make non-field arrays reactive', ->
    cards.push(new Card(true))
    expect(lastIsFlipped.get()).toBe(false)
  it 'should make array field sets do a full replacement', ->
    deck.cards = [new Card(true)]
    expect(lastInDeckIsFlipped.get()).toBe(true)
    deck.cards = [new Card(false)]
    expect(lastInDeckIsFlipped.get()).toBe(false)
  it 'should give back the same fields it was given', ->
    options = one: 'hello', two: 'world'
    rx.autoReactify(options)
    expect(options.one).toBe('hello')
    expect(options.two).toBe('world')
  it 'should leave observables unchanged', ->
    x = one: 'hello', two: 'world', three: (bind -> 0), four: rx.array([1,2])
    origThree = x.three
    origFour = x.four
    rx.autoReactify(x)
    expect(x.one).toBe('hello')
    expect(x.two).toBe('world')
    expect(x.three).toBe(origThree)
    expect(x.four).toBe(origFour)

describe 'flatten', ->
  flattened = mapped = xs = ys = i = null
  beforeEach ->
    xs = rx.array(['b','c'])
    ys = rx.array(['E','F'])
    i = rx.cell('i')
    flattened = rx.flatten [
      'A'
      xs.map (x) -> x.toUpperCase()
      'D'
      ys.map (y) -> y
      ['G','H']
      bind -> i.get().toUpperCase()
    ]
    mapped = flattened.map (x) -> x.toLowerCase()
  it 'should flatten and react to observables', ->
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','G','H','I'])
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','g','h','i'])
    i.set('j')
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','G','H','J'])
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','g','h','j'])
    ys.push('f')
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','f','G','H','J'])
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','f','g','h','j'])
  it 'should not flatten jQuery objects (which are array-like)', ->
    flattened = rx.flatten [
      $('body')
      bind -> $('<div/>')
    ]
    expect(flattened.at(0).is('body')).toBe(true)
    expect(flattened.at(1).is('div')).toBe(true)
  it 'should remove undefineds/nulls (for convenient conditionals)', ->
    flattened = rx.flatten [
      1
      rx.cell()
      undefined
      [undefined]
      bind -> undefined
      rx.array([null])
      2
    ]
    expect(flattened.all()).toEqual([1,2])

describe 'Ev', ->
  it 'should support scoped subscription', ->
    ev = new Ev()
    n = 0
    hits = 0
    listener = (x) ->
      hits += 1
      expect(x).toBe(n)
    ev.pub(n += 1)
    ev.scoped listener, ->
      ev.pub(n += 1)
      ev.pub(n += 1)
    ev.pub(n += 1)
    expect(hits).toBe(2)

describe 'nested mutations', ->
  it 'should not complain about directly nested mutations in dependent binds of dependent binds', ->
    a = rx.cell(0)
    b = rx.cell()
    aa = bind -> b.set(a.get())
    aaa = bind -> b.set(aa.get()+1)
    a.set(0)
    expect(aaa.get()).toBe(0)
  it 'should not complain about directly nested mutations in listeners', ->
    a = rx.cell()
    b = rx.cell()
    a.onSet.sub ([old,val]) -> b.set(val)
    expect(-> a.set(0)).not.toThrow()

describe 'snap', ->
  it 'should shield from enclosing bind', ->
    runs = []
    x = rx.cell()
    y = bind ->
      y = rx.snap(-> x.get())
      runs.push(null)
      y
    expect(runs.length).toBe(1)
    expect(y.get()).toBeNull()
    x.set(0)
    expect(runs.length).toBe(1)
    expect(y.get()).toBeNull()

describe 'skipFirst', ->
  it 'should skip first', ->
    x = rx.cell()
    xs = []
    x.onSet.sub rx.skipFirst ([o,n]) -> xs.push(n)
    expect(xs.length).toBe(0)
    x.set(true)
    expect(xs.length).toBe(1)
    expect(xs[0]).toBe(true)
    x.set(false)
    expect(xs.length).toBe(2)
    expect(xs[1]).toBe(false)

describe 'asyncBind', ->
  it 'should work synchronously as well', ->
    x = rx.cell(0)
    y = rx.asyncBind 'none', -> @done(@record -> x.get())
    expect(y.get()).toBe(0)
    x.set(1)
    expect(y.get()).toBe(1)
  it 'should work asynchronously', ->
    x = rx.cell(0)
    y = rx.asyncBind 'none', ->
      _.defer => @done(x.get())
    runs ->
      expect(y.get()).toBe('none')
      x.set(1)
      expect(y.get()).toBe('none')
    waitsFor (-> y.get() == 1), 'The async should have fired', 1
  it 'should not be a SrcCell', ->
    x = rx.cell(0)
    y = rx.asyncBind 'none', -> @done(x.get())
    expect(-> y.set(0)).toThrow()
  it 'should support @done called from within @record', ->
    x = rx.cell()
    y = rx.cell(1)
    z = rx.asyncBind 'none', -> @record =>
      return @done(0) if not x.get()?
      sum = x.get() + y.get()
      _.defer => @done(sum)
    w = bind -> z.get()
    expect(w.get()).toBe(0)
    runs -> x.set(2)
    waitsFor (-> w.get() == 3), 'The async should have fired', 1
    runs -> x.set(5)
    waitsFor (-> w.get() == 6), 'The async should have fired', 1

describe 'lagBind', ->
  x = y = evaled = null
  beforeEach ->
    x = rx.cell(0)
    evaled = false
    y = rx.lagBind 20, 'none', ->
      evaled = true
      x.get()
  it 'should remain at init value until the given lag', ->
    runs ->
      expect(y.get()).toBe('none')
      setTimeout (->
        expect(evaled).toBe(false)
        expect(y.get()).toBe('none')
      ), 10
    waitsFor (-> evaled), 21
    runs ->
      expect(y.get()).toBe(0)
  it 'should (after init) update on upstream set by (and not before) the given lag', ->
    waitsFor (-> evaled), 21
    runs ->
      evaled = false
      x.set(1)
      setTimeout (->
        expect(evaled).toBe(false)
        expect(y.get()).toBe(0)
      ), 10
    waitsFor (-> evaled), 21
    runs ->
      expect(y.get()).toBe(1)
  it 'should not evaluate as long as new refresh keeps getting scheduled', ->
    start = new Date().getTime()
    y = rx.lagBind 20, 'none', ->
      evaled = true
      x.get()
    waitsFor (-> evaled), 21 # nothing we can do before first evaluation
    runs ->
      evaled = false
      for snooze in [10, 20, 30, 40]
        do (snooze) ->
          setTimeout (->
            expect(evaled).toBe(false)
            x.set(snooze)
          ), snooze
    waitsFor (-> evaled), 61

describe 'postLagBind', ->
  x = y = evaled = null
  beforeEach ->
    x = rx.cell(20)
    evaled = false
    y = rx.postLagBind 'none', ->
      evaled = true
      val: x.get(), ms: x.get()
  it 'should evaluate immediately but not update value', ->
    expect(evaled).toBe(true)
    expect(y.get()).toBe('none')
  it 'should evaluate by (and not before) the given lag', ->
    runs ->
      expect(y.get()).toBe('none')
      x.set(15)
      setTimeout (-> expect(y.get()).toBe('none')), 5
    waitsFor (-> y.get() == 15), 16
  it 'should not update as long as new refresh keeps getting scheduled', ->
    runs ->
      for snooze in [5, 10, 15, 20]
        do (snooze) ->
          setTimeout (->
            expect(y.get()).toBe('none')
            x.set(snooze)
          ), snooze
    waitsFor (-> y.get() == 20), 41

describe 'cssify', ->
  it 'should work', ->
    cssified = rxt.cssify {
      display: 'none' if false
      borderLeft: 5
      margin: '0'
    }
    expect(cssified).toBe('border-left: 5px; margin: 0;')
  it 'should automatically work for style attr', ->
    staticElt = div {style: {fontSize: 10}}
    disp = rx.cell()
    dynamic = div {style: bind -> {display: disp.get()}}
    expect(staticElt.attr('style')).toBe('font-size: 10px;')
    expect(dynamic.attr('style')).toBe('')
    disp.set('none')
    expect(dynamic.attr('style')).toBe('display: none;')

describe 'cast', ->
  it 'should work', ->
    opts =
      change: ->
      selected: bind -> 0
      label: 'hello'
      options: [1..3]
      values: bind -> [1..3]
    casted = rxt.cast opts,
      selected: 'cell'
      label: 'cell'
      options: 'array'
      values: 'array'
    expect(casted.change).toBe(opts.change)
    expect(casted.selected).toBe(opts.selected)
    expect(casted.label.get()).toBe(opts.label)
    expect(casted.options.all()).toEqual(opts.options)
    expect(casted.values.all()).toEqual(opts.values.get())

describe 'autoSub', ->
  it 'should automatically unsubscribe on bind exit', ->
    count = 0
    x = rx.cell()
    y = rx.cell()
    z = bind ->
      rx.autoSub x.onSet, -> count += 1
      y.get()
    x.set(0)
    x.set(1)
    y.set(0)
    x.set(2)
    x.set(3)
    expect(count).toBe(6)

describe 'RawHtml', ->
  frag = null
  beforeEach ->
    frag = rxt.rawHtml('<em>hi</em>')
  it 'should support insertion of arbitrary HTML elements', ->
    $x = div {class: 'stuff'}, bind -> [frag]
    expect($x.html()).toBe('<em>hi</em>')
  it 'should only be supported if containing single element', ->
    frag = rxt.rawHtml('<em>hi</em><em>ho</em>')
    expect(->
      div {class: 'stuff'}, bind -> frag
    ).toThrow()
    expect(->
      div {class: 'stuff'}, bind -> rxt.rawHtml('')
    ).toThrow()

describe 'rxt', ->
  it 'should take as contents (arrays of) strings, elements, RawHtml, or $', ->
    for useArray in [false, true]
      maybeArray = (x) -> if useArray then [x] else x
      expect(outerHtml(div(maybeArray('hi')))).toBe('<div>hi</div>')
      expect(outerHtml(div(maybeArray($('<em>hi</em>'))))).toBe('<div><em>hi</em></div>')
      expect(outerHtml(div(maybeArray(rxt.rawHtml('<em>hi</em>'))))).toBe('<div><em>hi</em></div>')
      expect(outerHtml(div(maybeArray($('<em>hi</em>')[0])))).toBe('<div><em>hi</em></div>')

describe 'cellToArray', ->
  it 'should propagate minimal splices for primitives', ->
    x = rx.cell([1,2,3])
    y = rx.cell([4,5,6])
    z = bind -> _.flatten([x.get(), y.get()])
    zs = rx.cellToArray(z)
    rx.autoSub zs.onChange, rx.skipFirst ([index, removed, added]) ->
      expect([index, removed, added]).toEqual([2, [3], [0]])
    x.set([1,2,0])
  it 'should propagate minimal splices for objects', ->
    x = rx.cell([1,2,{x:3}])
    y = rx.cell([[4],5,'6'])
    z = bind -> _.flatten([x.get(), y.get()])
    zs = rx.cellToArray(z)
    rx.autoSub zs.onChange, rx.skipFirst ([index, removed, added]) ->
      expect([index, removed, added]).toEqual([2, [{x:3}], [0]])
    x.set([1,2,0])
  it 'should not confuse different types', ->
    x = rx.cell([1,'1'])
    y = bind -> x.get()
    ys = rx.cellToArray(y)
    rx.autoSub ys.onChange, rx.skipFirst ([index, removed, added]) ->
      expect(false).toBe(true)
    x.set([1,'1'])

describe 'DepArray', ->
  it 'should concat arrays efficiently', ->
    xs = rx.array([-1])
    ys = rx.array()
    zs = rx.concat(xs, ys)
    rx.autoSub zs.onChange, ([index, removed, added]) ->
      expect(zs.raw()).toEqual(xs.raw().concat(ys.raw()))
    xs.push(2)
    ys.insert(5, 0)
    xs.push(4)
    ys.insert(4, 0)
    xs.put(2, 3)
    ys.push(6)
    xs.splice(0, 1, 0, 1)
    ys.replace([4,5,6,7])

describe 'SrcArray', ->
  it 'should not change anything if remove query not found', ->
    xs = rx.array([0])
    xs.remove(1)
    expect(xs.raw()).toEqual([0])
  it 'should issue only minimal events for updates', ->
    xs = rx.array([1,2,3])
    lastEvent = null
    xs.onChange.sub (e) -> lastEvent = e
    expect(lastEvent).toEqual([0,[],[1,2,3]])
    lastEvent = null
    xs.update([1,2,3])
    expect(lastEvent).toEqual(null)
    lastEvent = null
    xs.update([1,2])
    expect(lastEvent).toEqual([2,[3],[]])

describe 'IndexedArray', ->
  it 'should update indexes', ->
    xs = rx.array(['a','b','c'])
    ys = xs.indexed().map (x,i) ->
      bind -> "#{x} #{i.get()}"
    readYs = -> ys.map((x) -> x.get()).raw()
    expect(readYs()).toEqual(['a 0','b 1','c 2'])
    xs.removeAt(1)
    expect(readYs()).toEqual(['a 0','c 1'])
    xs.insert('B', 1)
    expect(readYs()).toEqual(['a 0','B 1','c 2'])

describe 'smushClasses', ->
  it 'should remove undefined', ->
    expect(rxt.smushClasses([
      'alpha'
      'beta'
      'gamma' if true
      'delta' if false
      'epsilon'
    ])).toBe('alpha beta gamma epsilon')

describe 'smartUidify', ->
  it 'should return JSON string of scalars', ->
    expect(rx.smartUidify(0)).toBe('0')
    expect(rx.smartUidify('0')).toBe('"0"')
  it 'should attach non-enumerable __rxUid to objects', ->
    for x in [{}, []]
      uid = rx.smartUidify(x)
      expect(uid).toEqual(jasmine.any(Number))
      expect(_.keys(x)).toEqual([])
      expect(x.__rxUid).toBe(uid)

describe 'lift', ->
  it 'should have no effect on empty objects', ->
    expect(rx.lift({})).toEqual({})
  it 'should convert POJO attributes to observable ones', ->
    x = {x:0, y:[], z:{}, n:null}
    expect(rx.lift(x)).toBe(x)
    expect(x.x).toEqual(jasmine.any(rx.ObsCell))
    expect(x.y).toEqual(jasmine.any(rx.ObsArray))
    expect(x.z).toEqual(jasmine.any(rx.ObsCell))
    expect(x.n).toEqual(jasmine.any(rx.ObsCell))
    expect(
      x:x.x.get()
      y:x.y.all()
      z:x.z.get()
      n:x.n.get()
    ).toEqual({x:0, y:[], z:{}, n:null})

describe 'transaction', ->
  it 'should buffer up events', ->
    x = rx.cell(5)
    y = rx.cell(0)
    z = bind -> x.get() + y.get()
    rx.transaction =>
      x.set(0)
      expect(z.get()).toBe(5)
      y.set(5)
      expect(z.get()).toBe(5)
    expect(z.get()).toBe(5)
