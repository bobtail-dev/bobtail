bind = rx.bind
describe 'source cell', ->
  src = null
  beforeEach -> src = rx.cell()
  it 'initially contains null', ->
    expect(src.get()).toBe(null)
  it 'has get value that is same as last set value', ->
    src.set(1)
    expect(src.get()).toBe(1)

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
    size = rx.cell(10)
    elt = rxt.tags.header {
      class: 'my-class'
      style: bind -> "font-size: #{size.get()}px"
      id: 'my-elt'
      click: ->
      init: -> @data('foo', 'bar')
    }, bind -> [
      'hello world'
      rxt.tags.button ['click me']
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
  x = cb = null
  beforeEach ->
    x = new rx.map({a:0})
    cb = jasmine.createSpy('cb')
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
