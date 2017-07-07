{jasmine, _, $, rx} = window
{snap, bind, Ev, rxt, rxv} = rx
div = rxt.tags.div
outerHtml = ($x) -> $x.clone().wrap('<p>').parent().html()

jasmine.CATCH_EXCEPTIONS = false

describe 'ObsBase', -> it 'should start', ->

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
describe 'smushClasses', ->
  it 'should remove undefined', ->
    expect(rxt.smushClasses([
      'alpha'
      'beta'
      'gamma' if true
      'delta' if false
      'epsilon'
    ])).toBe('alpha beta gamma epsilon')

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
    expect(handler.calls.count()).toEqual(0)
    onSaleCell.set(true)
    expect(handler.calls.count()).toEqual(1)
    expect(handler.calls.first().args[0].$element).toBe($ul)
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated")
    expect(handler.calls.first().args[0].added.length).toBe(2)
    expect(handler.calls.first().args[0].removed.length).toBe(2)
    expect(handler.calls.first().args[0].updated).toBe(undefined)

    expect(handler.calls.mostRecent().args[0].$element).toBe($ul)
    expect(handler.calls.mostRecent().args[0].type).toBe("childrenUpdated")
    expect(handler.calls.mostRecent().args[0].added[0]).toBe($("li", $ul)[0])