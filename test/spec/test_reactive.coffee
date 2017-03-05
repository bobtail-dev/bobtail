{jasmine, _} = window
{snap, bind, Ev, rxt, rxv} = rx
div = rxt.tags.div
outerHtml = ($x) -> $x.clone().wrap('<p>').parent().html()

{jasmine} = window

jasmine.CATCH_EXCEPTIONS = false

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
    dep = bind -> src.get()
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
  describe 'object creation', ->
    size = elt = null
    beforeEach ->
      size = rx.cell(10)
      elt = rxt.tags.header {
        class: 'my-class'
        style: bind -> if size.get()? then "font-size: #{size.get()}px" else null
        id: 'my-elt'
        click: ->
        init: -> @data('foo', 'bar')
      }, bind -> [
        'hello world'
        rxt.tags.span bind -> if size.get()? then size.get() * 2
        rxt.tags.button ['click me']
      ]
    it 'should have the right tag', ->
      expect(elt.is('header')).toBe(true)
      expect(elt[0] instanceof Element).toBe(true)
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
      expect(elt.contents()[1].textContent).toBe('18')
      size.set()
      expect(elt.attr('style')).toBe(undefined)
      expect(elt.css('font-size')).toBe('')
      expect(elt.contents()[1].textContent).toBe('')
    it 'should have the given child contents', ->
      cont = elt.contents()
      child = cont.last()
      expect(cont.length).toBe(3)
      expect(cont[0]).toEqual(jasmine.any(Text))
      expect(cont[0].textContent).toBe('hello world')
      expect(cont[1].tagName).toBe('SPAN')
      expect(cont[1].textContent).toBe('20')
      expect(cont.last().is('button')).toBe(true)
      expect(cont.last().text()).toBe('click me')
    it 'should not have special attrs set', ->
      expect(elt.attr('init')).toBe(undefined)
      expect(elt.attr('click')).toBe(undefined)

  describe 'SVG object creation', ->
    elt = null
    beforeEach ->
      elt = rxt.svg_tags.rect {
        class: "shape"
        click: -> {}
        x: 10
        y: 20
      }, bind -> [
        rxt.svg_tags.animatetransform {
          attributeName: 'transform'
          begin: '0s'
          dur: '20s'
          type: 'rotate'
          from: '0 60 60'
          to: '360 60 60'
          repeatCount: 'indefinite'
        }
      ]

    it 'should have the right tag', ->
      expect(elt).toBeDefined()
      expect(elt instanceof SVGRectElement).toBe(true)
    it 'should have the set attributes', ->
      expect(elt.getAttribute('x')).toBe('10')
      expect(elt.getAttribute('class')).toBe('shape')
    it 'should have the given child contents', ->
      kids = elt.childNodes
      expect(kids.length).toBe(1)
      expect(kids[0] instanceof SVGElement).toBe(true)

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
  it "should work with reactive map functions", ->
    multiplierCell = rx.cell(1)
    $ul = rxt.tags.ul xs.map (f) -> rxt.tags.li f * multiplierCell.get()
    expect($(x).text() for x in $("li", $ul)).toEqual(["1", "2", "3"])
    multiplierCell.set(10)
    expect($(x).text() for x in $("li", $ul)).toEqual(["10", "20", "30"])


describe 'SrcArray', ->
  describe 'insert', ->
    it 'should insert elements before their target index', ->
      xs = rx.array []
      ys = rx.cellToArray bind -> xs.all()
      xs.insert 1, 0
      expect(ys.all()).toEqual [1]
      xs.insert 2, 0
      expect(ys.all()).toEqual [2, 1]
      xs.insert 3, 3
      expect(ys.all()).toEqual [2, 1, 3]
      xs.insert 5, -1
      expect(ys.all()).toEqual [2, 1, 5, 3]
      xs.insert 6, 5
      expect(ys.all()).toEqual [2, 1, 5, 3, 6]

  describe 'remove', ->
    it 'should not remove anything if element not found', ->
      xs = rx.array(['a','b','c'])
      xs.remove('d')
      expect(xs.all()).toEqual(['a','b','c'])
      xs.remove('b')
      expect(xs.all()).toEqual(['a','c'])

  describe 'removeAll', ->
    it 'should remove all elements that match the value', ->
      xs = rx.array(['a', 'b', 'a', 'c'])
      zs = rx.cellToArray bind -> xs.all()
      xs.removeAll('a')
      expect(xs.all()).toEqual ['b', 'c']
      expect(zs.all()).toEqual ['b', 'c']
    it 'should do nothing if no matching elements found', ->
      ys = rx.array(['b', 'c'])
      ys.removeAll('a')


  describe 'removeAt', ->
    it 'should remove elements by index and return the removed value', ->
      xs = rx.array [0, 1, 2, 3]
      ys = rx.cellToArray bind -> xs.all()

      x1 = xs.removeAt 1
      expect(xs.all()).toEqual [0, 2, 3]
      expect(ys.all()).toEqual [0, 2, 3]

      x2 = xs.removeAt 2

      expect(xs.all()).toEqual [0, 2]
      expect(ys.all()).toEqual [0, 2]
      expect(x1).toEqual 1
      expect(x2).toEqual 3

    it 'should not fail due to attempting to remove an element out of range', ->
      xs = rx.array [0, 2]
      ys = rx.cellToArray bind -> xs.all()
      expect(xs.removeAt 2).toBeUndefined()
      expect(xs.all()).toEqual [0, 2]
      expect(ys.all()).toEqual [0, 2]

  describe 'push', ->
    it 'should append elements to the array', ->
      xs = rx.array []
      ys = rx.cellToArray bind -> xs.all()

      xs.push 1
      xs.push 2
      xs.push 3

      expect(xs.all()).toEqual [1, 2, 3]
      expect(ys.all()).toEqual [1, 2, 3]


  describe 'pop', ->
    it 'should remove and return elements from the back of the array', ->
      xs = rx.array [1, 2, 3]
      ys = rx.cellToArray bind -> xs.all()

      expect(xs.pop()).toEqual 3
      expect(xs.all()).toEqual [1, 2]
      expect(xs.pop()).toEqual 2
      expect(xs.all()).toEqual [1]
      expect(xs.pop()).toEqual 1
      expect(xs.all()).toEqual []
      expect(ys.all()).toEqual []

    it 'should return undefined if the array is empty', ->
      expect(rx.array().pop()).toBeUndefined()


  describe 'put', ->
    it 'should replace the selected element', ->
      xs = rx.array [1, 2, 3, 4]
      ys = rx.cellToArray bind -> xs.all()

      xs.put(1, 10)
      expect(xs.all()).toEqual [1, 10, 3, 4]
      expect(ys.all()).toEqual [1, 10, 3, 4]
    it 'should append if the index is out of bounds', ->
      xs = rx.array []
      ys = rx.cellToArray bind -> xs.all()
      xs.put 12, 10
      expect(xs.all()).toEqual [10]
      expect(ys.all()).toEqual [10]


  describe 'replace', ->
    it 'should replace the entire array', ->
      xs = rx.array [1, 2, 3]
      ys = rx.cellToArray bind -> xs.all()

      xs.replace [1, 2, 4]
      expect(xs.all()).toEqual [1, 2, 4]
      expect(ys.all()).toEqual [1, 2, 4]

      xs.replace []
      expect(xs.all()).toEqual []
      expect(ys.all()).toEqual []

      xs.replace [10, 10, 10, 15]
      expect(xs.all()).toEqual [10, 10, 10, 15]
      expect(ys.all()).toEqual [10, 10, 10, 15]


  describe 'unshift', ->
    it 'should insert at the beginning of the array', ->
      xs = rx.array [3, 2, 1]
      ys = rx.cellToArray bind -> xs.all()

      xs.unshift 4

      expect(xs.all()).toEqual [4, 3, 2, 1]
      expect(ys.all()).toEqual [4, 3, 2, 1]

      xs.unshift 5
      expect(xs.all()).toEqual [5, 4, 3, 2, 1]
      expect(ys.all()).toEqual [5, 4, 3, 2, 1]


  describe 'shift', ->
    it 'should return undefined if the array is empty', ->
      xs = rx.array []
      expect(xs.shift()).toBeUndefined()
      expect(xs.all()).toEqual []

    it 'should remove and return the first element in the array', ->
      xs = rx.array [3, 2, 1]
      ys = rx.cellToArray bind -> xs.all()

      expect(xs.shift()).toEqual 3
      expect(xs.all()).toEqual [2, 1]
      expect(ys.all()).toEqual [2, 1]

      expect(xs.shift()).toEqual 2
      expect(xs.all()).toEqual [1]
      expect(ys.all()).toEqual [1]

      expect(xs.shift()).toEqual 1
      expect(xs.all()).toEqual []
      expect(ys.all()).toEqual []


  describe 'move', ->
    it 'should move the element to the index before its target', ->
      xs = rx.array [1, 2, 3, 4]
      ys = rx.cellToArray bind -> xs.all()
      xs.move 0, 1
      expect(xs.all()).toEqual [1, 2, 3, 4]
      expect(ys.all()).toEqual [1, 2, 3, 4]
      xs.move 0, 3
      expect(xs.all()).toEqual [2, 3, 1, 4]
      expect(ys.all()).toEqual [2, 3, 1, 4]
      xs.move 2, 4
      expect(xs.all()).toEqual [2, 3, 4, 1]
      expect(ys.all()).toEqual [2, 3, 4, 1]
      xs.move 3, 0
      expect(xs.all()).toEqual [1, 2, 3, 4]
      expect(ys.all()).toEqual [1, 2, 3, 4]

    it 'do nothing if the indices are the same', ->
      xs = rx.array [1, 2, 3, 4]
      ys = rx.cellToArray bind -> xs.all()
      [0...4].forEach (i) ->
        xs.move i, i
        expect(xs.all()).toEqual [1, 2, 3, 4]
        expect(ys.all()).toEqual [1, 2, 3, 4]

    it 'should throw an error if the target index is greater than @length', ->
      xs = rx.array [1, 2, 3, 4]
      expect(-> xs.move 0, 5).toThrow()

    it 'should throw an error if the target index is less than 0', ->
      xs = rx.array [1, 2, 3, 4]
      expect(-> xs.move 2, -1).toThrow()

    it 'should throw an error if the source index is greater than length', ->
      xs = rx.array [1, 2, 3, 4]
      expect(-> xs.move 4, 0).toThrow()

    it 'should throw an error if the source index is less than 0', ->
      xs = rx.array [1, 2, 3, 4]
      expect(-> xs.move -1, 2).toThrow()

  describe 'swap', ->
    it 'should swap elements at the specified indices', ->
      xs = rx.array [1, 2, 3, 4]
      ys = rx.cellToArray bind -> xs.all()

      xs.swap 0, 3
      expect(xs.all()).toEqual [4, 2, 3, 1]
      expect(ys.all()).toEqual [4, 2, 3, 1]

      xs.swap 3, 0
      expect(xs.all()).toEqual [1, 2, 3, 4]
      expect(ys.all()).toEqual [1, 2, 3, 4]

      xs.swap 2, 3
      expect(xs.all()).toEqual [1, 2, 4, 3]
      expect(ys.all()).toEqual [1, 2, 4, 3]

    it 'do nothing if the indices are the same', ->
      xs = rx.array [1, 2, 3, 4]
      ys = rx.cellToArray bind -> xs.all()
      [0...4].forEach (i) ->
        xs.move i, i
        expect(xs.all()).toEqual [1, 2, 3, 4]
        expect(ys.all()).toEqual [1, 2, 3, 4]

    it 'should throw an error if the target index is greater than @length', ->
      xs = rx.array [1, 2, 3, 4]
      expect(-> xs.swap 0, 4).toThrow()

    it 'should throw an error if the target index is less than 0', ->
      xs = rx.array [1, 2, 3, 4]
      expect(-> xs.swap 2, -1).toThrow()

    it 'should throw an error if the source index is greater or equal to length', ->
      xs = rx.array [1, 2, 3, 4]
      expect(-> xs.swap 4, 0).toThrow()

    it 'should throw an error if the source index is less than 0', ->
      xs = rx.array [1, 2, 3, 4]
      expect(-> xs.swap -1, 2).toThrow()


  describe 'reverse', ->
    it 'should reverse the SrcArray and return its new value', ->
      xs = rx.array [4, 3, 2, 1]
      ys = rx.cellToArray bind -> xs.all()
      expect(xs.reverse()).toEqual [1, 2, 3, 4]
      expect(xs.all()).toEqual [1, 2, 3, 4]
      expect(ys.all()).toEqual [1, 2, 3, 4]
    it 'should would with an empty array', ->
      zs = rx.array []
      expect(zs.reverse()).toEqual []
      expect(zs.all()).toEqual []


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
  it 'should capture, react, and cleanup like a regular bind', ->
    nums = rx.array([0,1])
    expect(nums.all()).toEqual([0,1])

    mapEvalCount = 0
    cleanupCount = 0
    bump = rx.cell(5)
    bumped = nums.map (num) ->
      mapEvalCount += 1
      rx.onDispose -> cleanupCount += 1
      num + bump.get()
    expect(bumped.all()).toEqual([5,6])
    bump.set(3)
    expect(bumped.all()).toEqual([3,4])

    noCapture = bind ->
      bumpDup = bind -> bump.get()
      bumped = nums.map (num) -> num + bump.get()
      0
    rx.autoSub noCapture.onSet, rx.skipFirst -> throw new Error()
    bump.set(2)
    nums.push(2)
    expect(noCapture.get()).toBe(0)

    startCleanupCount = cleanupCount
    nums.removeAt(2)
    expect(cleanupCount).toBe(startCleanupCount + 1)

    startMapEvalCount = mapEvalCount
    nums.push(2)
    expect(mapEvalCount).toBe(startMapEvalCount + 1)

    startMapEvalCount = mapEvalCount
    nums.put(2,4)
    expect(mapEvalCount).toBe(startMapEvalCount + 1)

    startMapEvalCount = mapEvalCount
    bump.set(0)
    expect(mapEvalCount).toBe(startMapEvalCount + 3)

describe 'ObsMap', ->
  x = cb = a = b = all = hasA = hasB = size = cbA = cbB = cbHasA = cbHasB = cbAll = cbSize = null
  beforeEach ->
    x = rx.map {a:0}
    cb = jasmine.createSpy 'cb'
    a = bind -> x.get 'a'
    b = bind -> x.get 'b'
    hasA = bind -> x.has 'a'
    hasB = bind -> x.has 'b'
    all = bind -> x.all()
    size = bind -> x.size()
    cbA = jasmine.createSpy 'cbA'
    cbB = jasmine.createSpy 'cbB'
    cbHasA = jasmine.createSpy 'cbHasA'
    cbHasB = jasmine.createSpy 'cbHasB'
    cbAll = jasmine.createSpy 'all'
    cbSize = jasmine.createSpy 'size'
    rx.autoSub a.onSet, cbA
    rx.autoSub b.onSet, cbB
    rx.autoSub hasA.onSet, cbHasA
    rx.autoSub hasB.onSet, cbHasB
    rx.autoSub all.onSet, cbAll
    rx.autoSub size.onSet, cbAll
    cbA.calls.reset()
    cbB.calls.reset()
    cbHasA.calls.reset()
    cbHasB.calls.reset()
    cbAll.calls.reset()
    cbSize.calls.reset()
  describe 'events', ->
    it 'should fire onChange event for replaced keys', ->
      rx.autoSub x.onChange, (map) -> cb map
      expect(x.put 'a', 1).toBe 0
      expect(cb.calls.mostRecent().args).toEqual [new Map [['a', [0,1]]]]
      expect(x.put 'a', 2).toBe 1
      expect(cb.calls.mostRecent().args).toEqual [new Map [['a', [1,2]]]]
    it 'should not fire onChange event if value does not change', ->
      rx.autoSub x.onChange, cb
      cb.calls.reset()
      x.put 'a', 0
      expect(cb).not.toHaveBeenCalled()
    it 'should fire onAdd event for new keys', ->
      rx.autoSub x.onAdd, cb
      cb.calls.reset()
      x.put 'b', 2
      expect(cb.calls.mostRecent().args).toEqual [new Map [['b', 2]]]
    it 'should not fire onAdd event for existing keys', ->
      rx.autoSub x.onAdd, cb
      cb.calls.reset()
      x.put 'a', 0
      expect(cb).not.toHaveBeenCalled()
      x.put 'a', 1
      expect(cb).not.toHaveBeenCalled()
    it 'should fire onRemove event for deleted keys', ->
      rx.autoSub x.onRemove, cb
      cb.calls.reset()
      x.remove 'a'
      expect(cb.calls.mostRecent().args).toEqual [new Map [['a', 0]]]
    it 'should not fire onRemove event if key is not in Map', ->
      rx.autoSub x.onRemove, cb
      cb.calls.reset()
      x.remove 'nope'
      expect(cb).not.toHaveBeenCalled()
  describe 'binds', ->
    it 'should re-evaluate .get() binds on any change', ->
      expect(a.get()).toBe 0
      expect(b.get()).toBeUndefined()
      x.put 'a', 1
      expect(a.get()).toBe 1
      expect(b.get()).toBeUndefined()
      x.put 'b', 2
      expect(a.get()).toBe 1
      expect(b.get()).toBe 2
      x.remove 'a'
      expect(a.get()).toBeUndefined()
      expect(b.get()).toBe 2
    it 'should not re-evaluate binds on no-ops', ->
      x.put 'a', 0
      x.remove 'b'
      expect(cbA).not.toHaveBeenCalled()
      expect(cbB).not.toHaveBeenCalled()
      expect(cbAll).not.toHaveBeenCalled()
      expect(cbHasA).not.toHaveBeenCalled()
      expect(cbHasB).not.toHaveBeenCalled()
      expect(cbSize).not.toHaveBeenCalled()
      expect(a.get()).toBe 0
      expect(b.get()).toBe undefined
      expect(hasA.get()).toBe true
      expect(hasB.get()).toBe false
      expect(all.get()).toEqual new Map [['a', 0]]
      expect(size.get()).toEqual 1
    it 'should re-evaluate .has() or .size() binds on any additions and removals', ->
      expect(hasA.get()).toBe true
      expect(hasB.get()).toBe false
      expect(size.get()).toBe 1
      x.remove 'a'
      expect(hasA.get()).toBe false
      expect(size.get()).toBe 0
      x.put 'b', 42
      expect(hasB.get()).toBe true
      expect(size.get()).toBe 1
      x.put {}, 50
      expect(size.get()).toBe 2
    it 'should not re-evaluate .has() or .size() binds when keys are not added or removed', ->
      x.put 'a', 42
      x.remove 'b'
      expect(cbHasA).not.toHaveBeenCalled()
      expect(cbHasB).not.toHaveBeenCalled()
      expect(cbSize).not.toHaveBeenCalled()
    it 'should re-evaluate .all() binds on any change', ->
      expect(all.get()).toEqual new Map [['a', 0]]
      x.put('a', 1)
      expect(all.get()).toEqual new Map [['a', 1]]
      x.put('b', 2)
      expect(all.get()).toEqual new Map [['a', 1], ['b', 2]]
      x.remove('a')
      expect(all.get()).toEqual new Map [['b', 2]]
  describe 'SrcMap mutations', ->
    it 'should support update() via object, pair array, and Map', ->
      called = {}
      rx.autoSub a.onSet, ([o,n]) -> called.a = [o,n]
      expect(a.get()).toBe 0
      expect(called.a).toEqual [null, 0]
      expect(x.update {a: 1, b: 2}).toEqual new Map [['a', 0]]
      expect(a.get()).toBe 1
      expect(b.get()).toBe 2
      expect(called.a).toEqual [0, 1]
      expected = new Map [['a', 0], ['b', 1]]
      expect(x.all()).toEqual expected
      expect(x.update [['b', 2], ['c', 3]]).toEqual expected
      expect(called.a).toEqual [1, undefined]
      expected = new Map [['b', 2], ['c', 3]]
      expect(x.all()).toEqual expected
      expect(x.update new Map [[]]).toEqual expected
    it 'should support put', ->
      expect(x.put 'a', 1).toBe 0
      expect(x.put 'a', 2).toBe 1
      expect(x.put 'b', 10).toBe undefined
      expect(x.put 'b', 20).toBe 10
    it 'should support remove', ->
      expect(x.remove 'a').toBe 0
      expect(x.remove 'b').toBe undefined
    it 'should support clear', ->
      rx.autoSub x.onRemove, cb
      cb.calls.reset()
      expect(x.clear()).toEqual new Map [['a', 0]]
      cb.calls.reset()
      expect(x.clear()).toEqual new Map []
      expect(cb).not.toHaveBeenCalled()

  it 'should support non-string keys', ->
    obj = {zzz: 777}
    x.put obj, 888
    expect(x.get obj).toBe 888
    expect(x.has obj).toBe true
    x.remove obj
    expect(x.has obj).toBe false
    x.update [[obj, 999]]
    expect(x.get obj).toBe 999
    expect(x.has obj).toBe true
  describe 'initialization', ->
    it 'should support initialization by object', ->
      y = rx.map {a: 0, b: 1}
      expect(y.all()).toEqual new Map [['a', 0], [b, 1]]
    it 'should support initialization by array of pairs', ->
      arr = []
      y = rx.map [['a', 42], [arr, 0]]
      expect(y.all()).toEqual new Map [['a', 42], [arr, 0]]
    it 'should support initialization by Map', ->
      arr = []
      y = rx.map new Map [['a', 42], [arr, 0]]
      expect(y.all()).toEqual new Map [['a', 42], [arr, 0]]


describe 'ObsSet', ->
  x = cb = all = hasA = hasB = size = cbHasA = cbHasB = cbAll = cbSize = null
  beforeEach ->
    x = rx.set ['a']
    cb = jasmine.createSpy 'cb'
    hasA = bind -> x.has 'a'
    hasB = bind -> x.has 'b'
    all = bind -> x.all()
    size = bind -> x.size()
    cbHasA = jasmine.createSpy 'cbHasA'
    cbHasB = jasmine.createSpy 'cbHasB'
    cbAll = jasmine.createSpy 'all'
    cbSize = jasmine.createSpy 'size'
    rx.autoSub hasA.onSet, cbHasA
    rx.autoSub hasB.onSet, cbHasB
    rx.autoSub all.onSet, cbAll
    rx.autoSub size.onSet, cbSize
    cbHasA.calls.reset()
    cbHasB.calls.reset()
    cbAll.calls.reset()
    cbSize.calls.reset()
  describe 'events', ->
    it 'should fire onChange event for new keys', ->
      rx.autoSub x.onChange, cb
      cb.calls.reset()
      x.put 'b'
      expect(cb.calls.mostRecent().args).toEqual [[new Set(['b']), new Set()]]
    it 'should not fire onChange event for existing keys', ->
      rx.autoSub x.onChange, cb
      cb.calls.reset()
      x.put 'a'
      expect(cb).not.toHaveBeenCalled()
      x.put 'a'
      expect(cb).not.toHaveBeenCalled()
    it 'should fire onChange event for deleted keys', ->
      rx.autoSub x.onChange, cb
      cb.calls.reset()
      x.remove 'a'
      expect(cb.calls.mostRecent().args).toEqual [[new Set(['a']), new Set()]]
    it 'should not fire onChange event if key is not in Set', ->
      rx.autoSub x.onChange, cb
      cb.calls.reset()
      x.remove 'nope'
      expect(cb).not.toHaveBeenCalled()
  describe 'binds', ->
    it 'should not re-evaluate .all() binds on no-ops', ->
      x.put 'a'
      x.remove 'b'
      expect(cbAll).not.toHaveBeenCalled()
      expect(all.get()).toEqual new Set ['a']
    it 'should re-evaluate .has() and .size() binds on any additions and removals', ->
      expect(hasA.get()).toBe true
      expect(hasB.get()).toBe false
      expect(size.get()).toBe 1
      x.remove 'a'
      expect(size.get()).toBe 0
      expect(hasA.get()).toBe false
      x.put 'b'
      expect(hasB.get()).toBe true
      expect(size.get()).toBe 1
      x.put {a: 42}
      expect(size.get()).toBe 2
    it 'should not re-evaluate any binds when values are not added or removed', ->
      x.put 'a'
      x.remove 'b'
      expect(cbHasA).not.toHaveBeenCalled()
      expect(cbHasB).not.toHaveBeenCalled()
      expect(cbAll).not.toHaveBeenCalled()
      expect(cbSize).not.toHaveBeenCalled()
      rx.transaction =>
        x.put 'b'
        x.remove 'b'
        x.remove 'a'
        x.put 'a'
      expect(cbHasA).not.toHaveBeenCalled()
      expect(cbHasB).not.toHaveBeenCalled()
      expect(cbAll).not.toHaveBeenCalled()
      expect(cbSize).not.toHaveBeenCalled()
    it 'should re-evaluate .all() binds on any change', ->
      expect(all.get()).toEqual new Set ['a']
      x.put 'b'
      expect(all.get()).toEqual new Set ['a', 'b']
      x.remove 'a'
      expect(all.get()).toEqual new Set ['b']
  describe 'SrcSet mutations', ->
    it 'should support update', ->
      expect(x.update ['zzzyx', 42]).toEqual new Set ['a']
      expect(x.update new Set 'xkcd').toEqual new Set ['zzzyx', 42]
    it 'should support put', ->
      expect(x.put 42).toBe 42
      expect(x.has 42).toBe true
      expect(x.put 42).toBe 42
      expect(x.has 42).toBe true
      expect(x.put 43).toBe 43
      expect(x.has 42).toBe true
      expect(x.has 43).toBe true
    it 'should support remove', ->
      expect(x.remove 'a').toBe 'a'
  it 'should support non-string values', ->
    obj = {zzz: 777}
    x.put obj
    expect(x.has obj).toBe true
    x.remove obj
    expect(x.has obj).toBe false


describe 'ObsSet operations', ->
  x = y = z = null
  beforeEach ->
    x = rx.set ['a', 'c', []]
    y = rx.set ['a', {}, 'b']
    z = new Set ['a', {}, 'b']
  it 'should support union', ->
    reactive = x.union y
    simple = x.union z
    expect(reactive.all()).toEqual new Set ['a', 'b', 'c', {}, []]
    expect(simple.all()).toEqual new Set ['a', 'b', 'c', {}, []]
    x.put 42
    expect(reactive.all()).toEqual new Set [42, 'a', 'b', 'c', {}, []]
    expect(simple.all()).toEqual new Set [42, 'a', 'b', 'c', {}, []]
    y.put 42
    expect(reactive.all()).toEqual new Set [42, 'a', 'b', 'c', {}, []]
    expect(simple.all()).toEqual new Set [42, 'a', 'b', 'c', {}, []]
    x.put 50
    expect(reactive.all()).toEqual new Set [42, 50, 'a', 'b', 'c', {}, []]
    expect(simple.all()).toEqual new Set [42, 50, 'a', 'b', 'c', {}, []]
    y.put 60
    expect(reactive.all()).toEqual new Set [60, 42, 50, 'a', 'b', 'c', {}, []]
    expect(simple.all()).toEqual new Set [42, 50, 'a', 'b', 'c', {}, []]
  it 'should support intersection', ->
    reactive = x.intersection y
    simple = x.intersection z
    expect(reactive.all()).toEqual new Set ['a']
    expect(simple.all()).toEqual new Set ['a']
    x.put 42
    expect(reactive.all()).toEqual new Set ['a']
    expect(simple.all()).toEqual new Set ['a']
    y.put 42
    expect(reactive.all()).toEqual new Set [42, 'a']
    expect(simple.all()).toEqual new Set ['a']
    x.put 50
    expect(reactive.all()).toEqual new Set [42, 'a']
    expect(simple.all()).toEqual new Set ['a']
    y.put 60
    expect(reactive.all()).toEqual new Set [42, 'a']
    expect(simple.all()).toEqual new Set ['a']
  it 'should support difference', ->
    reactive = x.difference y
    simple = x.difference z
    expect(reactive.all()).toEqual new Set ['c', []]
    expect(simple.all()).toEqual new Set ['c', []]
    x.put 42
    expect(reactive.all()).toEqual new Set ['c', 42, []]
    expect(simple.all()).toEqual new Set ['c', 42, []]
    y.put 42
    expect(reactive.all()).toEqual new Set ['c', []]
    expect(simple.all()).toEqual new Set ['c', 42, []]
    x.put 50
    expect(reactive.all()).toEqual new Set ['c', 50, []]
    expect(simple.all()).toEqual new Set ['c', 42, 50, []]
    y.put 60
    expect(reactive.all()).toEqual new Set ['c', 50, []]
    expect(simple.all()).toEqual new Set ['c', 42, 50, []]
  it 'should support symmetricDifference', ->
    reactive = x.symmetricDifference y
    simple = x.symmetricDifference z
    expect(reactive.all()).toEqual new Set ['c', [], {}, 'b']
    expect(simple.all()).toEqual new Set ['c', [], {}, 'b']
    x.put 42
    expect(reactive.all()).toEqual new Set ['c', [], 42, {}, 'b']
    expect(simple.all()).toEqual new Set ['c', [], {}, 42, 'b']
    y.put 42
    expect(reactive.all()).toEqual new Set ['c', [], {}, 'b']
    expect(simple.all()).toEqual new Set ['c', [], {}, 42, 'b']
    x.put 50
    expect(reactive.all()).toEqual new Set ['c', 50, [], {}, 'b']
    expect(simple.all()).toEqual new Set [50, 'c', [], {}, 42, 'b']
    y.put 60
    expect(reactive.all()).toEqual new Set ['c', 50, [], {},  60, 'b']
    expect(simple.all()).toEqual new Set [50, 'c', [], {}, 42, 'b']


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
    zset = rx.set ['X', 'K', [], 'C', 'D', [new Set ['XKCD!']]]
    new Set [50]
    flattened = rx.flatten [
      'A'
      xs.map (x) -> x.toUpperCase()
      'D'
      ys.map (y) -> y
      ['G','H']
      bind -> i.get().toUpperCase()
      zset.all()
    ]
    mapped = flattened.map (x) -> x.toLowerCase()
  it 'should flatten and react to observables', ->
    expect(flattened.all()).toEqual ['A','B','C','D','E','F','G','H','I','X','K','C','D','XKCD!']
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','g','h','i','x','k','c','d','xkcd!'])
    i.set('j')
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','G','H','J','X','K','C','D','XKCD!'])
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','g','h','j','x','k','c','d','xkcd!'])
    ys.push('f')
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','f','G','H','J','X','K','C','D','XKCD!'])
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','f','g','h','j','x','k','c','d','xkcd!'])
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
  it 'should flatten recursively', ->
    flattened = rx.flatten [
      1
      rx.cell()
      rx.cell([rx.array([42]), [500, undefined, rx.set [800]], [null, new Set [null]]])
      undefined
      [undefined]
      bind -> undefined
      rx.array([null])
      rx.array [
        rx.array(["ABC"])
        rx.array([rx.array(["DEF"]), ["GHI"]]), [null], rx.array [[null]]]
      "XYZ"
      2
    ]
    expect(snap -> flattened.all()).toEqual [
      1, 42, 500, 800, "ABC", "DEF", "GHI", "XYZ", 2
    ]

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

describe 'mutating', ->
  it 'should not emit warnings if wrapped in a hideMutationWarnings block', ->
    warnSpy = jasmine.createSpy('warn1')
    oldWarningFn = rx._recorder.fireMutationWarning
    rx._recorder.fireMutationWarning = warnSpy
    a = rx.cell(0)
    b = rx.cell(2)
    expect(warnSpy).not.toHaveBeenCalled()
    c = bind -> rx.hideMutationWarnings ->
      b.set rx.snap -> b.get() + 1
      a.get() * 2
    expect(warnSpy).not.toHaveBeenCalled()
    expect(rx.snap -> c.get()).toBe 0
    expect(rx.snap -> b.get()).toBe 3

    a.set 2
    expect(rx.snap -> c.get()).toBe 4
    expect(warnSpy).not.toHaveBeenCalled()
    rx._recorder.fireMutationWarning = oldWarningFn

  it 'should otherwise fire a warning', ->
    warnSpy = jasmine.createSpy('warn2')
    oldWarningFn = rx._recorder.fireMutationWarning
    rx._recorder.fireMutationWarning = warnSpy
    a = rx.cell(0)
    b = rx.cell(2)
    expect(warnSpy).not.toHaveBeenCalled()
    c = bind ->
      b.set rx.snap -> b.get() + 1
      a.get() * 2
    expect(warnSpy.calls.count()).toBe 1
    expect(rx.snap -> c.get()).toBe 0
    expect(rx.snap -> b.get()).toBe 3
    a.set 2
    expect(rx.snap -> c.get()).toBe 4
    expect(warnSpy.calls.count()).toBe 2
    rx._recorder.fireMutationWarning = oldWarningFn


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
      y = snap(-> x.get())
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
  describe 'synchronous tests', ->
    it 'should work synchronously as well', ->
      x = rx.cell(0)
      y = rx.asyncBind 'none', -> @done(@record -> x.get())
      expect(y.get()).toBe(0)
      x.set(1)
      expect(y.get()).toBe(1)
    it 'should not be a SrcCell', ->
      x = rx.cell(0)
      y = rx.asyncBind 'none', -> @done(x.get())
      expect(-> y.set(0)).toThrow()
    it 'should enforce one-time record', ->
      x = rx.cell(0)
      rx.asyncBind 'none', ->
        @record => x.get()
        _.defer => expect(=> @done(@record => x.get())).toThrow()

  describe 'asynchronous tests', ->
    # _.defer essentially enqueues a new task for the JS VM to run.
    # Because we're not using AJAX requests, we can thus use _.defer instead
    # of callback handlers, which would be very tricky to work with here.

    it 'should work asynchronously', ->
      x = rx.cell(0)
      y = rx.asyncBind 'none', ->
        _.defer => @done(x.get())
      expect(y.get()).toBe('none')
      x.set(1)
      expect(y.get()).toBe('none')
      _.defer -> expect(y.get()).toBe(1)
    it 'should work asynchronously with recording at the end', ->
      x = rx.cell(0)
      y = rx.asyncBind 'none', ->
        _.defer => @done(@record => x.get())
      expect(y.get()).toBe('none')
      x.set(1)
      expect(y.get()).toBe('none')
      _.defer -> expect(y.get()).toBe(1)
    it 'should work asynchronously with recording at the beginning', ->
      x = rx.cell(0)
      y = rx.asyncBind 'none', ->
        xx = @record => x.get()
        _.defer => @done(xx)
      expect(y.get()).toBe('none')
      x.set(1)
      expect(y.get()).toBe('none')
      _.defer -> expect(y.get()).toBe 1
    it 'should support @done called from within @record', ->
      x = rx.cell()
      y = rx.cell(1)
      z = rx.asyncBind 'none', -> @record =>
        return @done(0) if not x.get()?
        sum = x.get() + y.get()
        _.defer => @done(sum)
      w = bind -> z.get()
      expect(w.get()).toBe(0)
      _.defer ->
        x.set(2)
        _.defer ->
          expect(w.get()).toBe 3
          x.set(5)
          _.defer ->
            expect(w.get()).toBe 6

describe 'promiseBind', ->
  it 'should work', ->
    sleep = (wait) ->
      deferred = $.Deferred()
      setTimeout(
        -> deferred.resolve(42 + wait)
        wait
      )
      deferred.promise()
    waitTime = rx.cell(10)
    closure = {}
    secretToLife = rx.promiseBind null, ->
      c = sleep(waitTime.get())
      closure.callback = c
      c
    expect(secretToLife.get()).toBe(null)
    closure.callback.done ->
      expect(secretToLife.get()).toBe == 52
      waitTime.set(5)
      closure.callback.done ->
        expect(secretToLife.get()).toBe 47

describe 'lagBind', ->
  x = y = evaled = start = null
  beforeEach ->
    x = rx.cell 0
    rx.autoSub x.onSet, ->
      evaled = $.Deferred()
    y = rx.lagBind 30, 'none', ->
      _.defer -> evaled.resolve true
      x.get()
  it 'should remain at init value until the given lag', ->
    expect(y.get()).toBe 'none'
    setTimeout (->
      expect(evaled.state()).toBe 'pending'
      expect(y.get()).toBe 'none'
    ), 10
    evaled.done -> expect(y.get()).toBe 0
  it 'should (after init) update on upstream set by (and not before) the given lag', (done) ->
    evaled.done ->
      x.set(1)
      setTimeout(
        ->
          expect(y.get()).toBe 0
          setTimeout(
            ->
              expect(y.get()).toBe 1
              done()
            60
          )
        10
      )
  it 'should not evaluate as long as new refresh keeps getting scheduled', ->
    # potentially flaky test :(
    expect(y.get()).toBe 'none'
    setTimeout(
      -> # nothing we can do before first evaluation
        for snooze in [5, 10, 15, 20]
          do (snooze) ->
            setTimeout (->
              expect(y.get()).toBe 0
              x.set(snooze)
            ), snooze
        setTimeout(
          -> expect(y.get()).toBe 20
          60
        )
      30
    )

describe 'postLagBind', ->
  x = y = evaled = null
  beforeEach ->
    x = rx.cell 30
    y = rx.postLagBind 'none', ->
      r = val: x.get(), ms: x.get()
      return r
  it 'should evaluate immediately but not update value', (done) ->
    _.defer ->
      expect(y.get()).toBe('none')
      done()
  it 'should evaluate by (and not before) the given lag', (done) ->
    expect(snap -> y.get()).toBe('none')
    x.set(15)
    setTimeout (-> expect(snap -> y.get()).toBe('none')), 5
    setTimeout(
      ->
        expect(y.get()).toBe(15)
        done()
      60
    )
  it 'should not update as long as new refresh keeps getting scheduled', (done) ->
    for snooze in [5, 10, 15, 20]
      do (snooze) ->
        setTimeout (->
          expect(y.get()).toBe('none')
          x.set(snooze)
        ), snooze
    setTimeout(
      ->
        expect(y.get()).toBe 20
        done()
      60
    )



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
  it 'should take as contents (arrays of) numbers, strings, elements, RawHtml, $ or null', ->
    for useArray in [false, true]
      maybeArray = (x) -> if useArray then [x] else x
      expect(outerHtml(div(maybeArray(2)))).toBe('<div>2</div>')
      expect(outerHtml(div(maybeArray(null)))).toBe('<div></div>')
      expect(outerHtml(div(maybeArray('hi')))).toBe('<div>hi</div>')
      expect(outerHtml(div(maybeArray($('<em>hi</em>'))))).toBe('<div><em>hi</em></div>')
      expect(outerHtml(div(maybeArray(rxt.rawHtml('<em>hi</em>'))))).toBe('<div><em>hi</em></div>')
      expect(outerHtml(div(maybeArray($('<em>hi</em>')[0])))).toBe('<div><em>hi</em></div>')

describe 'cellToMap', ->
  it 'should correctly track changes', ->
    x = rx.map {a: 42}
    y = rx.cellToMap bind ->
      x.all()
    expect(rx.snap -> y.all()).toEqual new Map [['a', 42]]
    x.put 'b', 17
    expect(rx.snap -> y.all()).toEqual new Map [['a', 42], ['b', 17]]
    x.put 'c', 4
    expect(rx.snap -> y.all()).toEqual new Map [['a', 42], ['b', 17], ['c', 4]]
    x.update new Map []
    expect(rx.snap -> y.all()).toEqual new Map []
    obj = {}
    x.update new Map [[obj, 0]]
    expect(rx.snap -> y.all()).toEqual new Map [[obj, 0]]

describe 'cellToSet', ->
  it 'should correctly track changes', ->
    obj = {}
    x = rx.set ['a', obj, 42]
    y = rx.cellToSet bind -> x.all()
    expect(rx.snap -> y.all()).toEqual new Set ['a', obj, 42]
    x.put 'b'
    expect(rx.snap -> y.all()).toEqual new Set ['a', obj, 42, 'b']
    x.put 'c'
    expect(rx.snap -> y.all()).toEqual new Set ['a', obj, 42, 'b', 'c']
    x.update new Set []
    expect(rx.snap -> y.all()).toEqual new Set []


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
      expect(zs.all()).toEqual(xs.all().concat(ys.all()))
    xs.push(2)
    ys.insert(5, 0)
    xs.push(4)
    ys.insert(4, 0)
    xs.put(2, 3)
    ys.push(6)
    xs.splice(0, 1, 0, 1)
    ys.replace([4,5,6,7])
  it 'should behave correctly if the last element is removed', ->
    foo = rx.array [1]
    bar = rx.cellToArray bind -> foo.all() # easy way to get a DepArray
    expect(bar instanceof rx.DepArray).toBe(true)
    foo.removeAt(0)
    expect(snap -> foo.all().length).toBe(0)
    expect(snap -> bar.all().length).toBe(0)

describe 'SrcArray', ->
  it 'should not change anything if remove query not found', ->
    xs = rx.array([0])
    xs.remove(1)
    expect(xs.all()).toEqual([0])
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

describe 'ObsArray.indexed', ->
  it 'should update indexes', ->
    xs = rx.array(['a','b','c'])
    ys = xs.indexed().map (x,i) ->
      bind -> "#{x} #{i.get()}"
    readYs = -> ys.map((x) -> x.get()).all()
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
  it 'should skip over already-observable members', ->
    c = {x: bind(-> 0), y: rx.array(), z: rx.map()}
    {x,y,z} = c
    rx.lift(c)
    # expect nothing to change
    expect(c.x).toBe(x)
    expect(c.y).toBe(y)
    expect(c.z).toBe(z)

describe 'transaction', ->
  it 'should buffer up events', ->
    x = rx.cell(5)
    y = rx.cell(0)
    z = bind -> x.get() + y.get()
    rx.transaction ->
      x.set(0)
      expect(z.get()).toBe(5)
      y.set(5)
      expect(z.get()).toBe(5)
    expect(z.get()).toBe(5)

describe 'onElementAttrsChanged', ->
  it 'should trigger for each changed attribute', ->
    rxt.events.enabled = true
    handler = jasmine.createSpy()
    rx.autoSub rxt.events.onElementAttrsChanged, handler

    stateCell = rx.cell("safe")
    offsetCell = rx.cell(0)
    $div = rxt.tags.div {
      class: bind -> ["notif", "notif--#{stateCell.get()}"]
      style: bind -> {left: offsetCell.get()}
      otherThing: "yes"
    }

    expect(handler.calls.count()).toBe(2)
    expect(handler).toHaveBeenCalledWith({$element: $div, attr: "class"})
    expect(handler).toHaveBeenCalledWith({$element: $div, attr: "style"})

    handler.calls.reset()
    stateCell.set("danger")
    expect(handler.calls.count()).toBe(1)
    expect(handler).toHaveBeenCalledWith({$element: $div, attr: "class"})

    handler.calls.reset()
    offsetCell.set(10)
    expect(handler.calls.count()).toBe(1)
    expect(handler).toHaveBeenCalledWith({$element: $div, attr: "style"})

describe 'onElementChildrenChanged', ->
  it 'should work for bind body', ->
    rxt.events.enabled = true
    handler = jasmine.createSpy()
    rx.autoSub rxt.events.onElementChildrenChanged, handler

    stateCell = rx.cell("safe")
    offsetCell = rx.cell(0)
    $div = rxt.tags.div bind -> stateCell.get()

    expect(handler.calls.count()).toBe(1)
    expect(handler).toHaveBeenCalledWith({$element: $div, type: "rerendered"})

    handler.calls.reset()
    stateCell.set("danger")
    expect(handler.calls.count()).toBe(1)
    expect(handler).toHaveBeenCalledWith({$element: $div, type: "rerendered"})

  it "should work for reactive array body", ->
    rxt.events.enabled = true
    handler = jasmine.createSpy()
    rx.autoSub rxt.events.onElementChildrenChanged, handler

    items = rx.array([{name: "Chicken feet", price: 10}])

    $ul = rxt.tags.ul items.map (item) -> rxt.tags.li item

    expect(handler.calls.count()).toBe(1)
    expect(handler.calls.first().args[0].$element).toBe($ul)
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated")
    expect(handler.calls.first().args[0].removed.length).toBe(0)
    expect(handler.calls.first().args[0].added.length).toBe(1)
    expect(handler.calls.first().args[0].added[0]).toBe($("li", $ul)[0])

    handler.calls.reset()
    items.push({name: "Intestines", price: 5})
    expect(handler.calls.count()).toBe(1)
    expect(handler.calls.first().args[0].$element).toBe($ul)
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated")
    expect(handler.calls.first().args[0].removed.length).toBe(0)
    expect(handler.calls.first().args[0].added.length).toBe(1)
    expect(handler.calls.first().args[0].added[0]).toBe($("li", $ul)[1])

    handler.calls.reset()
    items.insert({name: "Intestines", price: 5}, 0)
    expect(handler.calls.count()).toBe(1)
    expect(handler.calls.first().args[0].$element).toBe($ul)
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated")
    expect(handler.calls.first().args[0].removed.length).toBe(0)
    expect(handler.calls.first().args[0].added.length).toBe(1)
    expect(handler.calls.first().args[0].added[0]).toBe($("li", $ul)[0])

    handler.calls.reset()
    items.removeAt(0)
    expect(handler.calls.count()).toBe(1)
    expect(handler.calls.first().args[0].$element).toBe($ul)
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated")
    expect(handler.calls.first().args[0].added.length).toBe(0)
    expect(handler.calls.first().args[0].removed.length).toBe(1)

    handler.calls.reset()
    items.replace([{name: "Wonton"}, {name: "smelly tofu"}])
    expect(handler.calls.count()).toBe(1)
    expect(handler.calls.first().args[0].$element).toBe($ul)
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated")
    expect(handler.calls.first().args[0].added.length).toBe(2)
    expect(handler.calls.first().args[0].added[0]).toBe($("li", $ul)[0])
    expect(handler.calls.first().args[0].added[1]).toBe($("li", $ul)[1])
    expect(handler.calls.first().args[0].removed.length).toBe(2)

  it "should work with reactive map function", ->
    rxt.events.enabled = true
    handler = jasmine.createSpy()
    rx.autoSub rxt.events.onElementChildrenChanged, handler

    onSaleCell = rx.cell(false)
    items = rx.array([{name: "Chicken feet", price: 10}, {name: "buns", price: 5}])

    $ul = rxt.tags.ul items.map (item) ->
      rxt.tags.li if onSaleCell.get() then item.price * 0.1 else item.price

    expect(handler.calls.count()).toEqual(1)
    expect(handler.calls.first().args[0].$element).toBe($ul)
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated")
    expect(handler.calls.first().args[0].added.length).toBe(2)
    expect(handler.calls.first().args[0].added[0]).toBe($("li", $ul)[0])
    expect(handler.calls.first().args[0].added[1]).toBe($("li", $ul)[1])
    expect(handler.calls.first().args[0].removed.length).toBe(0)

    handler.calls.reset()
    onSaleCell.set(true)
    expect(handler.calls.count()).toEqual(2)
    expect(handler.calls.first().args[0].$element).toBe($ul)
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated")
    expect(handler.calls.first().args[0].added).toBe(undefined)
    expect(handler.calls.first().args[0].removed).toBe(undefined)
    expect(handler.calls.first().args[0].updated.length).toBe(1)
    expect(handler.calls.first().args[0].updated[0]).toBe($("li", $ul)[0])

    expect(handler.calls.mostRecent().args[0].$element).toBe($ul)
    expect(handler.calls.mostRecent().args[0].type).toBe("childrenUpdated")
    expect(handler.calls.mostRecent().args[0].added).toBe(undefined)
    expect(handler.calls.mostRecent().args[0].removed).toBe(undefined)
    expect(handler.calls.mostRecent().args[0].updated.length).toBe(1)
    expect(handler.calls.mostRecent().args[0].updated[0]).toBe($("li", $ul)[1])
