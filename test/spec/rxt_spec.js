import $ from 'jquery';
import * as rx from '../../src/main.js';
let {snap, bind, Ev, rxt} = rx;
let {tags} = rxt;
let {div} = tags;
let outerHtml = $x => $x.clone().wrap('<p>').parent().html();

jasmine.CATCH_EXCEPTIONS = false;

describe('tag', () => {
  describe('object creation', () => {
    let elt;
    let size = (elt = null);
    let clz;
    beforeEach(function() {
      size = rx.cell(10);
      clz = rx.cell('my-class');
      elt = rxt.tags.header({
        class: () => clz.get(),
        style: () => { if (size.get() != null) { return `font-size: ${size.get()}px`; } else { return null; } },
        id: rx.bind(() => 'my-elt'),
        click() {},
        init() { return this.data('foo', 'bar'); }
      }, () => [
        'hello world',
        rxt.tags.span(
          bind(() => {
            if (size.get() != null) {
              return size.get() * 2;
            }
          })
        ),
        rxt.tags.button(() => ['click me'])
      ]);
      return elt;
    });
    it('should have the right tag', () => {
      expect(elt.is('header')).toBe(true);
      expect(elt[0] instanceof Element).toBe(true);
    });
    it('should have the set attributes', () => {
      expect(elt.prop('class')).toBe('my-class');
      expect(elt.attr('style')).toBe('font-size: 10px');
      expect(elt.prop('id')).toBe('my-elt');
      expect(elt.hasClass('my-class')).toBe(true);
      expect(elt.css('font-size')).toBe('10px');
      expect(elt.data('foo')).toBe('bar');
    });
    it('should update attrs in response to size changes', () => {
      size.set(9);
      expect(elt.attr('style')).toBe('font-size: 9px');
      expect(elt.css('font-size')).toBe('9px');
      expect(elt.contents()[1].textContent).toBe('18');
      size.set();
      expect(elt.attr('style')).toBe(undefined);
      expect(elt.css('font-size')).toBe('');
      expect(elt.contents()[1].textContent).toBe('');
      clz.set('foobar');
      expect(elt.prop('class')).toBe('foobar');
    });
    it('should have the given child contents', () => {
      let cont = elt.contents();
      let child = cont.last();
      expect(cont.length).toBe(3);
      expect(cont[0]).toEqual(jasmine.any(Text));
      expect(cont[0].textContent).toBe('hello world');
      expect(cont[1].tagName).toBe('SPAN');
      expect(cont[1].textContent).toBe('20');
      expect(cont.last().is('button')).toBe(true);
      expect(cont.last().text()).toBe('click me');
    });
    return it('should not have special attrs set', () => {
      expect(elt.attr('init')).toBe(undefined);
      expect(elt.attr('click')).toBe(undefined);
    });
  });

  return describe('SVG object creation', () => {
    let elt = null;
    beforeEach(() =>
      elt = rxt.svg_tags.rect({
        class: "shape",
        click() { return {}; },
        x: 10,
        y: 20
      }, bind(() => [
        rxt.svg_tags.animatetransform({
          attributeName: 'transform',
          begin: '0s',
          dur: '20s',
          type: 'rotate',
          from: '0 60 60',
          to: '360 60 60',
          repeatCount: 'indefinite'
        })
      ] )));

    it('should have the right tag', () => {
      expect(elt).toBeDefined();
      expect(elt instanceof SVGRectElement).toBe(true);
    });
    it('should have the set attributes', () => {
      expect(elt.getAttribute('x')).toBe('10');
      expect(elt.getAttribute('class')).toBe('shape');
    });
    return it('should have the given child contents', () => {
      let kids = elt.childNodes;
      expect(kids.length).toBe(1);
      expect(kids[0] instanceof SVGElement).toBe(true);
    });
  });
});

describe('rxt of observable array', () => {
  let elt;
  let xs = (elt = null);
  beforeEach(() => {
    xs = rx.array([1,2,3]);
    return elt = rxt.tags.ul(xs.map(x => x % 2 === 0 ? `plain ${x}` : rxt.tags.li(`item ${x}`)));
  });
  it('should be initialized to the given contents', () => {
    let cont = elt.contents();
    expect(cont.length).toBe(3);
    expect(cont.eq(0).is('li')).toBe(true);
    expect(cont.eq(0).text()).toBe('item 1');
    expect(cont[1]).toEqual(jasmine.any(Text));
    expect(cont.eq(1).text()).toBe('plain 2');
    expect(cont.eq(2).is('li')).toBe(true);
    expect(cont.eq(2).text()).toBe('item 3');
  });
  it('should update contents in response to array changes', () => {
    xs.splice(0, 3, 0, 1, 2);
    let cont = elt.contents();
    expect(cont[0]).toEqual(jasmine.any(Text));
    expect(cont.eq(0).text()).toBe('plain 0');
    expect(cont.eq(1).is('li')).toBe(true);
    expect(cont.eq(1).text()).toBe('item 1');
    expect(cont[2]).toEqual(jasmine.any(Text));
    expect(cont.eq(2).text()).toBe('plain 2');
  });
  return it("should work with reactive map functions", () => {
    let x;
    let multiplierCell = rx.cell(1);
    let $ul = tags.ul(xs.map(f => tags.li(f * multiplierCell.get())));
    expect((() => {
      let result = [];
      for (x of Array.from($("li", $ul))) {         result.push($(x).text());
      }
      return result;
    })()).toEqual(["1", "2", "3"]);
    multiplierCell.set(10);
    expect((() => {
      let result1 = [];
      for (x of Array.from($("li", $ul))) {         result1.push($(x).text());
      }
      return result1;
    })()).toEqual(["10", "20", "30"]);
  });
});

describe('flattenWeb', () => {
  let i, mapped, xs, ys;
  let flattened = (mapped = (xs = (ys = (i = null))));
  beforeEach(() => {
    xs = rx.array(['b','c']);
    ys = rx.array(['E','F']);
    i = rx.cell('i');
    let zset = rx.set(['X', 'K', [], 'C', 'D', [new Set(['XKCD!'])]]);
    new Set([50]);
    flattened = rxt.flattenWeb([
      'A',
      xs.map(x => x.toUpperCase()),
      bind(() => 'D'),
      ys.map(y => () => y),
      ['G','H'],
      () => () => i.get().toUpperCase(),
      zset.all()
    ]);
    mapped = flattened.map(x => x.toLowerCase());
  });
  it('should flatten and react to observables', () => {
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','G','H','I','X','K','C','D','XKCD!']);
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','g','h','i','x','k','c','d','xkcd!']);
    i.set('j');
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','G','H','J','X','K','C','D','XKCD!']);
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','g','h','j','x','k','c','d','xkcd!']);
    ys.push('f');
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','f','G','H','J','X','K','C','D','XKCD!']);
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','f','g','h','j','x','k','c','d','xkcd!']);
  });
  it('should not flatten jQuery objects (which are array-like)', () => {
    flattened = rxt.flattenWeb([
      $('body'),
      () => bind(() => $('<div/>'))
    ]);
    expect(flattened.at(0).is('body')).toBe(true);
    expect(flattened.at(1).is('div')).toBe(true);
  });
  it('should remove undefineds/nulls (for convenient conditionals)', () => {
    flattened = rxt.flattenWeb([
      1,
      rx.cell(),
      undefined,
      [undefined],
      bind(() => undefined),
      rx.array([null]),
      2
    ]);
    expect(flattened.all()).toEqual([1,2]);
  });
  return it('should flatten recursively', () => {
    flattened = rxt.flattenWeb([
      1,
      rx.cell(),
      rx.cell([rx.array([42]), [500, undefined, rx.set([800])], [null, new Set([null])]]),
      undefined,
      [undefined],
      () => () => bind(() => 'wat'),
      bind(() => undefined),
      rx.array([null]),
      rx.array([
        rx.array(["ABC"]),
        rx.array([rx.array(["DEF"]), ["GHI"]]), [null], rx.array([[null]])]),
      "XYZ",
      2
    ]);
    expect(snap(() => flattened.all())).toEqual([
      1, 42, 500, 800, 'wat', "ABC", "DEF", "GHI", "XYZ", 2
    ]);
  });
});
describe('RawHtml', () => {
  let frag = null;
  beforeEach(() => frag = rxt.rawHtml('<em>hi</em>'));
  it('should support insertion of arbitrary HTML elements', () => {
    let $x = div({class: 'stuff'}, bind(() => [frag]));
    expect($x.html()).toBe('<em>hi</em>');
  });
  return it('should only be supported if containing single element', () => {
    frag = rxt.rawHtml('<em>hi</em><em>ho</em>');
    expect(() => div({class: 'stuff'}, bind(() => frag))).toThrow();
    expect(() => div({class: 'stuff'}, bind(() => rxt.rawHtml('')))).toThrow();
  });
});

describe('rxt', () =>
  it('should take as contents (arrays of) numbers, strings, elements, RawHtml, $, or null', () =>
    (() => {
      let result = [];
      for (var useArray of [false, true]) {
        let maybeArray = x => useArray ? [x] : x;
        expect(outerHtml(div(maybeArray(2)))).toBe('<div>2</div>');
        expect(outerHtml(div(maybeArray(null)))).toBe('<div></div>');
        expect(outerHtml(div(maybeArray('hi')))).toBe('<div>hi</div>');
        expect(outerHtml(div(maybeArray($('<em>hi</em>'))))).toBe('<div><em>hi</em></div>');
        expect(outerHtml(div(maybeArray(rxt.rawHtml('<em>hi</em>'))))).toBe('<div><em>hi</em></div>');
        result.push(expect(outerHtml(div(maybeArray($('<em>hi</em>')[0])))).toBe('<div><em>hi</em></div>'));
      }
      return result;
    })()
  )
);
describe('smushClasses', () =>
  it('should remove undefined', () =>
    expect(rxt.smushClasses([
      'alpha',
      'beta',
      true ? 'gamma' : undefined,
      false ? 'delta' : undefined,
      'epsilon'
    ])).toBe('alpha beta gamma epsilon')
  )
);

describe('onElementAttrsChanged', () =>
  it('should trigger for each changed attribute', () => {
    rxt.events.enabled = true;
    let handler = jasmine.createSpy();
    rx.autoSub(rxt.events.onElementAttrsChanged, handler);

    let stateCell = rx.cell("safe");
    let offsetCell = rx.cell(0);
    let $div = tags.div({
      class: bind(() => ["notif", `notif--${stateCell.get()}`]),
      style: bind(() => ({left: offsetCell.get()})),
      otherThing: "yes"
    });

    expect(handler.calls.count()).toBe(2);
    expect(handler).toHaveBeenCalledWith({$element: $div, attr: "class"});
    expect(handler).toHaveBeenCalledWith({$element: $div, attr: "style"});

    handler.calls.reset();
    stateCell.set("danger");
    expect(handler.calls.count()).toBe(1);
    expect(handler).toHaveBeenCalledWith({$element: $div, attr: "class"});

    handler.calls.reset();
    offsetCell.set(10);
    expect(handler.calls.count()).toBe(1);
    expect(handler).toHaveBeenCalledWith({$element: $div, attr: "style"});
  })
 );

describe('onElementChildrenChanged', () => {
  it("should work for reactive array body", () => {
    rxt.events.enabled = true;
    let handler = jasmine.createSpy();
    rx.autoSub(rxt.events.onElementChildrenChanged, handler);

    let items = rx.array([{name: "Chicken feet", price: 10}]);

    let $ul = tags.ul(items.map(item => tags.li(item)));

    expect(handler.calls.count()).toBe(1);
    expect(handler.calls.first().args[0].$element).toBe($ul);
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated");
    expect(handler.calls.first().args[0].removed.length).toBe(0);
    expect(handler.calls.first().args[0].added.length).toBe(1);
    expect(handler.calls.first().args[0].added[0]).toBe($("li", $ul)[0]);

    handler.calls.reset();
    items.push({name: "Intestines", price: 5});
    expect(handler.calls.count()).toBe(1);
    expect(handler.calls.first().args[0].$element).toBe($ul);
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated");
    expect(handler.calls.first().args[0].removed.length).toBe(0);
    expect(handler.calls.first().args[0].added.length).toBe(1);
    expect(handler.calls.first().args[0].added[0]).toBe($("li", $ul)[1]);

    handler.calls.reset();
    items.insert({name: "Intestines", price: 5}, 0);
    expect(handler.calls.count()).toBe(1);
    expect(handler.calls.first().args[0].$element).toBe($ul);
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated");
    expect(handler.calls.first().args[0].removed.length).toBe(0);
    expect(handler.calls.first().args[0].added.length).toBe(1);
    expect(handler.calls.first().args[0].added[0]).toBe($("li", $ul)[0]);

    handler.calls.reset();
    items.removeAt(0);
    expect(handler.calls.count()).toBe(1);
    expect(handler.calls.first().args[0].$element).toBe($ul);
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated");
    expect(handler.calls.first().args[0].added.length).toBe(0);
    expect(handler.calls.first().args[0].removed.length).toBe(1);

    handler.calls.reset();
    items.replace([{name: "Wonton"}, {name: "smelly tofu"}]);
    expect(handler.calls.count()).toBe(1);
    expect(handler.calls.first().args[0].$element).toBe($ul);
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated");
    expect(handler.calls.first().args[0].added.length).toBe(2);
    expect(handler.calls.first().args[0].added[0]).toBe($("li", $ul)[0]);
    expect(handler.calls.first().args[0].added[1]).toBe($("li", $ul)[1]);
    expect(handler.calls.first().args[0].removed.length).toBe(2);
  });

  return it("should work with reactive map function", () => {
    rxt.events.enabled = true;
    let handler = jasmine.createSpy();
    rx.autoSub(rxt.events.onElementChildrenChanged, handler);

    let onSaleCell = rx.cell(false);
    let items = rx.array([{name: "Chicken feet", price: 10}, {name: "buns", price: 5}]);

    let $ul = tags.ul(items.map(item => tags.li(onSaleCell.get() ? item.price * 0.1 : item.price))
    );

    expect(handler.calls.count()).toEqual(1);
    expect(handler.calls.first().args[0].$element).toBe($ul);
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated");
    expect(handler.calls.first().args[0].added.length).toBe(2);
    expect(handler.calls.first().args[0].added[0]).toBe($("li", $ul)[0]);
    expect(handler.calls.first().args[0].added[1]).toBe($("li", $ul)[1]);
    expect(handler.calls.first().args[0].removed.length).toBe(0);

    handler.calls.reset();
    expect(handler.calls.count()).toEqual(0);
    onSaleCell.set(true);
    expect(handler.calls.count()).toEqual(1);
    expect(handler.calls.first().args[0].$element).toBe($ul);
    expect(handler.calls.first().args[0].type).toBe("childrenUpdated");
    expect(handler.calls.first().args[0].added.length).toBe(2);
    expect(handler.calls.first().args[0].removed.length).toBe(2);
    expect(handler.calls.first().args[0].updated).toBe(undefined);

    expect(handler.calls.mostRecent().args[0].$element).toBe($ul);
    expect(handler.calls.mostRecent().args[0].type).toBe("childrenUpdated");
    expect(handler.calls.mostRecent().args[0].added[0]).toBe($("li", $ul)[0]);
  });
});

describe('abbreviated template syntax', () => {
  it("should work with variadic arguments", () => {
    expect(outerHtml(div(
      ["Sing to me, "],
      ["Muse, "],
      bind(() => "of the "),
      rxt.tags.strong("wrath"),
      " ",
      () => () => rxt.tags.em("of Achilles")
    ))).toBe(`<div>Sing to me, Muse, of the <strong>wrath</strong> <em>of Achilles</em></div>`);
  });
});

describe('normalizeTagArgs', () => {
  it("should work with variadic arguments", () => {
    expect(outerHtml(div(
      ["Sing to me, "],
      ["Muse, "],
      bind(() => "of the "),
      tags.strong("wrath"),
      " ",
      () => () => tags.em("of Achilles")
    ))).toBe(`<div>Sing to me, Muse, of the <strong>wrath</strong> <em>of Achilles</em></div>`);
  });
  it("should work with no/null-like args", () => {
    expect(rxt.normalizeTagArgs()).toEqual([{}, null]);
    expect(rxt.normalizeTagArgs(null)).toEqual([{}, null]);
    expect(rxt.normalizeTagArgs(null, null)).toEqual([{}, null]);
  });
  it("should work with attr object as only arg", () => {
    expect(rxt.normalizeTagArgs({})).toEqual([{}, null]);
    expect(rxt.normalizeTagArgs({abc: 'def'})).toEqual([{abc: 'def'}, null]);
  });
});


describe('normalizeTagArgs', () => {
  it("should work with no/null-like args", () => {
    expect(rxt.normalizeTagArgs()).toEqual([{}, null]);
    expect(rxt.normalizeTagArgs(null)).toEqual([{}, null]);
    expect(rxt.normalizeTagArgs(null, null)).toEqual([{}, null]);
  });
  it("should work with attr object as only arg", () => {
    expect(rxt.normalizeTagArgs({})).toEqual([{}, null]);
    expect(rxt.normalizeTagArgs({abc: 'def'})).toEqual([{abc: 'def'}, null]);
  });

  let types = new Map([
    ["String", "dancing"],
    ["Number", 101],
    ["hex", 0xdeadbeef],
    ["false", false],
    ["true", true],
    ["Array", ["YES", "NO"]],
    ["Element", $("<div>jquery</div>")[0]],
    ["SVGElement", $("<textpath>textual</textpath>")[0]],
    ["RawHtml", rxt.rawHtml("<div>42</div>")],
    ["$", $("<div>jquery</div>")],
    ["rx.ObsCell", rx.bind(() => 42)],
    ["rx.ObsArray", rx.bind(() => [42, 45]).toArray()],
    ["rx.ObsSet", rx.bind(() => [42, 45, 42]).toSet()],
    ["function", () => 42]
  ]);

  let attrs = {name: 'foo', class: 'bar'};

  describe("should work with contents of type ", () => {
    for(let [name, contents] of types.entries()) {
      it(name, () => {
        let normed = rxt.normalizeTagArgs(contents);
        expect(normed).toEqual([{}, contents]);

        let attrNormed = rxt.normalizeTagArgs(attrs, contents);
        expect(attrNormed).toEqual([attrs, contents]);
      })
    }
  });

  it("should work with variadic args", () => {
    let normalized = rxt.normalizeTagArgs(...types.values());
    let attred = rxt.normalizeTagArgs(attrs, ...types.values());
    expect(normalized).toEqual([{}, Array.from(types.values())]);
    expect(attred).toEqual([attrs, Array.from(types.values())]);
  });
});
