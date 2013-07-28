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
      init: -> @attr('data-foo', 'bar')
    }, bind -> [
      'hello world'
      rxt.tags.button ['click me']
    ]
  it 'should have the right tag', ->
    expect(elt.is('header')).toBe(true)
  it 'should have the set attributes', ->
    expect(elt.attr('class')).toBe('my-class')
    expect(elt.attr('style')).toBe('font-size: 10px')
    expect(elt.attr('id')).toBe('my-elt')
    expect(elt.attr('data-foo')).toBe('bar')
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
    expect(cont.first().text()).toBe('hello world')
    expect(cont.last().is('button')).toBe(true)
    expect(cont.last().text()).toBe('click me')
  it 'should not have special attrs set', ->
    expect(elt.attr('init')).toBe(undefined)
    expect(elt.attr('click')).toBe(undefined)
