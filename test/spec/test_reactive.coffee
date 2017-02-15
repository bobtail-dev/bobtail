{jasmine, _} = window
{snap, bind, Ev, rxt, rxv} = rx
div = rxt.tags.div
outerHtml = ($x) -> $x.clone().wrap('<p>').parent().html()

jasmine.CATCH_EXCEPTIONS = false
{}

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

describe 'ObsArray', ->
  describe 'all', ->
    it 'should return all items in the ObsArray', ->
      xs = rx.array []
      ys = rx.cellToArray bind -> xs.all()
      expect(snap -> ys.all()).toEqual []
      xs.push 1
      expect(snap -> ys.all()).toEqual [1]
      xs.push 2
      expect(snap -> ys.all()).toEqual [1, 2]
      xs.push 3
      expect(snap -> ys.all()).toEqual [1, 2, 3]
      xs.push 4
      expect(snap -> ys.all()).toEqual [1, 2, 3, 4]
      xs.update []
      expect(snap -> ys.all()).toEqual []
      xs.update []
      expect(snap -> ys.all()).toEqual []

  describe 'at', ->
    it 'should return the value of the array at a given index', ->
      arr = rx.array [4, 3, 2, 1, 0]
      expect(snap -> arr.at 0).toBe 4
      expect(snap -> arr.at 4).toBe 0
    it 'should update if the value of the array at that index changes', ->
      arr = rx.array [1, 2]

    it 'should return undefined if the index is invalid', ->
      arr = rx.array [0, 1, 2, 3, 4, 5]
      expect(snap -> arr.at -1).toBeUndefined()
      expect(snap -> arr.at 42).toBeUndefined()
      expect(snap -> arr.at undefined).toBeUndefined()
      expect(snap -> arr.at "foo").toBeUndefined()

  describe 'length', ->
    it 'should track the length of the array, and update only when the array length changes', ->
      count = 0
      arr = rx.array()
      len = bind -> arr.length()
      rx.autoSub len.onSet, rx.skipFirst -> count += 1
      expect(count).toBe 0
      expect(snap -> len.get()).toBe 0
      arr.push 1
      expect(snap -> len.get()).toBe 1
      expect(count).toBe 1
      arr.update [4]
      expect(snap -> len.get()).toBe 1
      expect(count).toBe 1
      arr.push 6
      expect(snap -> len.get()).toBe 2
      expect(count).toBe 2
      arr.pop()
      expect(snap -> len.get()).toBe 1
      expect(count).toBe 3
      arr.pop()
      expect(snap -> len.get()).toBe 0
      expect(count).toBe 4
      arr.pop()
      expect(snap -> len.get()).toBe 0
      expect(count).toBe 4
  describe 'transform', ->
    it 'should allow arbitrary transformation of an array, and track changes', ->
      arr = rx.array [1, 2, 3, 4, 5, 6]
      squaredEvens = arr.transform (array) -> array.filter((e) -> e % 2 == 0).map (e) -> e**2
      expect(snap -> squaredEvens.all()).toEqual [4, 16, 36]
      arr.push 8
      expect(snap -> squaredEvens.all()).toEqual [4, 16, 36, 64]
      arr.update []
      expect(snap -> squaredEvens.all()).toEqual []
  describe 'map', ->
    it '', -> # TODO
  describe 'filter', ->
    it 'should keep only elements that pass the provided test', ->
      arr = rx.array [1, 2, 3, 4, 5, 6]
      expect(snap -> arr.filter((e) -> e % 2 == 0).all()).toEqual [2, 4, 6]
      expect(snap -> arr.filter((e) -> e % 2 == 1).all()).toEqual [1, 3, 5]
    it 'should update when the array changes', ->

  describe 'slice', ->
    it 'should work like its analagous ES method', ->
      arr = rx.array [1, 2, 3, 4, 5, 6]
      expect(snap -> arr.slice(2, 4).all()).toEqual [3, 4]
      expect(snap -> arr.slice(0, 4).all()).toEqual [1, 2, 3, 4]
      expect(snap -> arr.slice(0, -1).all()).toEqual [1, 2, 3, 4, 5]
      expect(snap -> arr.slice(1, -2).all()).toEqual [2, 3, 4]
      expect(snap -> arr.slice(1).all()).toEqual [2, 3, 4, 5, 6]
      expect(snap -> arr.slice(-2).all()).toEqual [5, 6]
    it 'should correctly handle invalid indices', ->
      arr = rx.array [1, 2, 3, 4, 5, 6]
      expect(snap -> arr.slice(12, 28).all()).toEqual []
      expect(snap -> arr.slice(1, 0).all()).toEqual []
      expect(snap -> arr.slice(0, 12).all()).toEqual [1, 2, 3, 4, 5, 6]
      expect(snap -> arr.slice(-8, -1).all()).toEqual [1, 2, 3, 4, 5]
    it 'should track changes', ->
      arr = rx.array [1, 2, 3, 4, 5, 6]
      x = arr.slice 1, -1
      expect(snap -> x.all()).toEqual [2, 3, 4, 5]
      arr.push 7
      expect(snap -> x.all()).toEqual [2, 3, 4, 5, 6]
      arr.pop()
      expect(snap -> x.all()).toEqual [2, 3, 4, 5]
      arr.update([8, 9, 10])
      expect(snap -> x.all()).toEqual [9]
  describe 'reduce', ->
    it 'should work like its analagous ES method', ->
      xs = rx.array []
      y = bind -> xs.reduce(
        (accum, curr, i) ->
          return (accum - curr) * (-1) ** i
        0
      )
      z = bind -> xs.reduce(
        (accum, curr, i) -> accum + curr * (2 ** i)
        1
      )
      a = bind -> xs.reduce(
        (accum, curr, i, arr) -> accum + curr + i + arr.length
        0
      )
      expect(y.get()).toBe 0
      expect(z.get()).toBe 1
      expect(a.get()).toBe 0
      xs.replace [16, 8, 4, 2, 1]
      expect(y.get()).toBe -19
      expect(z.get()).toBe 81
      expect(a.get()).toBe 66
  describe 'reduceRight', ->
    it 'should work like its analagous ES method', ->
      xs = rx.array []
      y = bind -> xs.reduceRight(
        (accum, curr, i) ->
          return (accum - curr) * (-1) ** i
        0
      )
      z = bind -> xs.reduceRight(
        (accum, curr, i, arr) -> accum + curr * (2 ** (arr.length - i - 1))
        1
      )
      a = bind -> xs.reduceRight(
        (accum, curr, i, arr) -> accum + curr + i + arr.length
        0
      )
      expect(y.get()).toBe 0
      expect(z.get()).toBe 1
      expect(a.get()).toBe 0
      xs.replace [1, 2, 4, 8, 16]
      expect(y.get()).toBe -19
      expect(z.get()).toBe 81
      expect(a.get()).toBe 66
  describe 'every', ->
    it 'should return true if every element in the array passes the test', -> # TODO
      truthy = rx.array [1, 1, 1]
      falsy = rx.array [1, 1, 0]
      expect(snap -> truthy.every _.identity).toBe true
      expect(snap -> falsy.every _.identity).toBe false
    it 'should short circuit as soon as one element in the array fails', -> # TODO
      count = 0
      arr = rx.array [1, 1, 0, 1, 1]
      soma = bind -> arr.every (e) ->
        count += 1
        return e
      expect(count).toBe 3
      expect(snap -> soma.get()).toBe false
    it 'should recalculate whenever the array changes', -> # TODO
      test = rx.array [1, 1, 1]
      soma = bind -> test.every _.identity
      expect(snap -> soma.get()).toBe true
      test.push 0
      expect(snap -> soma.get()).toBe false
      test.pop()
      expect(snap -> soma.get()).toBe true
      test.put 1, 0
      expect(snap -> soma.get()).toBe false
  describe 'some', ->
    it 'should return true if any element in the array passes the test', -> # TODO
      truthy = rx.array [0, 0, 0, 0, 1, 0]
      falsy = rx.array [0, 0, 0]
      expect(snap -> truthy.some _.identity).toBe true
      expect(snap -> falsy.some _.identity).toBe false
    it 'should short circuit as soon as one element in the array succeeds', ->
      count = 0
      arr = rx.array [0, 0, 1, 0]
      soma = bind -> arr.some (e) ->
        count += 1
        return e
      expect(count).toBe 3
      expect(snap -> soma.get()).toBe true
    it 'should recalculate whenever the array changes', ->
      test = rx.array [0, 0, 0]
      soma = bind -> test.some _.identity
      expect(snap -> soma.get()).toBe false
      test.push 1
      expect(snap -> soma.get()).toBe true
      test.pop()
      expect(snap -> soma.get()).toBe false
      test.put 1, 1
      expect(snap -> soma.get()).toBe true
  describe 'indexOf', ->
    it 'should return -1 if not found', ->
      expect(snap -> rx.array([1,2,3]).indexOf 0).toBe -1
    it 'should return the index where the element is otherwise', ->
      expect(snap -> rx.array([1,2,3]).indexOf 3).toBe 2
      expect(snap -> rx.array([1,0,1,2,3]).indexOf 1, 2).toBe 2
    it 'should update when the underlying array changes', ->
      arr = rx.array([1,2,3])
      i = bind -> arr.indexOf 4
      expect(snap -> i.get()).toBe -1
      arr.push 4
      expect(snap -> i.get()).toBe 3

  describe 'lastIndexOf', ->
    it 'should return -1 if not found', ->
      expect(snap -> rx.array([1,2,3]).lastIndexOf 0).toBe -1
    it 'should return the index where the element is otherwise', ->
      expect(snap -> rx.array([1,2,3]).lastIndexOf 3).toBe 2
      expect(snap -> rx.array([1,2,3,0,3,0]).lastIndexOf 3, 3).toBe 2
    it 'should update when the underlying array changes', ->
      arr = rx.array [1,2,3]
      i = bind -> arr.lastIndexOf 4
      expect(snap -> i.get()).toBe -1
      arr.unshift 4
      expect(snap -> i.get()).toBe 0
      arr.push 4
      expect(snap -> i.get()).toBe 4
  describe 'join', ->
    it 'should return the empty string for empty arrays', ->
      expect(snap -> rx.array().join "abc").toEqual ''
    it 'should behave like ES join', ->
      expect(snap -> rx.array([1,2,3,4,5]).join ", ").toEqual '1, 2, 3, 4, 5'
    it 'should update when the source array changes', ->
      arr = rx.array []
      expect(snap -> arr.join ", ").toEqual ''
      arr.update [1,2,3,4,5]
      expect(snap -> arr.join ", ").toEqual '1, 2, 3, 4, 5'
      arr.put(2, 10)
      expect(snap -> arr.join ", ").toEqual '1, 2, 10, 4, 5'
      arr.pop()
      expect(snap -> arr.join ", ").toEqual '1, 2, 10, 4'
  describe 'first', ->
    it 'should be undefined for an empty array', ->
      xs = rx.array()
      z = bind -> xs.first()
      expect(z.get()).toBeUndefined()
  describe 'last', ->
    it 'should be undefined for an empty array', ->
      xs = rx.array()
      z = bind -> xs.last()
      expect(z.get()).toBeUndefined()
  describe 'indexed', ->
    it '', -> # TODO
  describe 'concat', ->
    it '', -> # TODO

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
    expect(cb).toHaveBeenCalledWith({'a':[0,1]})
  it 'should fire onAdd event for new keys', ->
    x.onAdd.sub cb
    x.put('b', 2)
    expect(cb).toHaveBeenCalledWith({'b': 2})
  it 'should fire onRemove event for deleted keys', ->
    x.onRemove.sub cb
    x.remove('a')
    expect(cb).toHaveBeenCalledWith({'a': 0})
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
  it 'should support update()', ->
    called = null
    a.onSet.sub rx.skipFirst ([o,n]) -> called = [o,n]
    x.update({a:0,b:1})
    expect(called).toBe(null)
    expect(x.all()).toEqual({a:0,b:1})
    x.update({b:2,c:3})
    expect(called).toEqual([0, undefined])
    expect(x.all()).toEqual({b:2,c:3})

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
  it 'should flatten recursively', ->
    flattened = rx.flatten [
      1
      rx.cell()
      rx.cell([rx.array([42]), [500, undefined, [800]], [null]])
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
            20
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
    x = rx.cell(20)
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
      25
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
        expect(y.get()).toBe(20)
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
    expect(snap -> y.all()).toEqual {a: 42}
    x.put 'b', 17
    expect(snap -> y.all()).toEqual {a: 42, b: 17}
    x.put 'c', 4
    expect(snap -> y.all()).toEqual {a: 42, b: 17, c: 4}
    x.update {}
    expect(snap -> y.all()).toEqual {}

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
