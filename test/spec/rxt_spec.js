let {jasmine, _, $, rx} = window;
let {snap, bind, Ev, rxt} = rx;
let { div } = rxt.tags;
let outerHtml = $x => $x.clone().wrap('<p>').parent().html();

jasmine.CATCH_EXCEPTIONS = false;

describe('tag', function() {
  describe('object creation', function() {
    let elt;
    let size = (elt = null);
    let cls = rx.cell('my-class');
    beforeEach(function() {
      size = rx.cell(10);
      elt = rxt.tags.header({
        class: () => cls.get(),
        style: bind(function() { if (size.get() != null) { return `font-size: ${size.get()}px`; } else { return null; } }),
        id: 'my-elt',
        click() {},
        init() { return this.data('foo', 'bar'); }
      }, () => [
        'hello world',
        rxt.tags.span(
          bind(function() {
            if (size.get() != null) {
              return size.get() * 2;
            }
          })
        ),
        rxt.tags.button(['click me'])
      ]);
      return elt;
    });
    it('should have the right tag', function() {
      expect(elt.is('header')).toBe(true);
      return expect(elt[0] instanceof Element).toBe(true);
    });
    it('should have the set attributes', function() {
      expect(elt.prop('class')).toBe('my-class');
      expect(elt.attr('style')).toBe('font-size: 10px');
      expect(elt.prop('id')).toBe('my-elt');
      expect(elt.hasClass('my-class')).toBe(true);
      expect(elt.css('font-size')).toBe('10px');
      return expect(elt.data('foo')).toBe('bar');
    });
    it('should update attrs in response to size changes', function() {
      size.set(9);
      expect(elt.attr('style')).toBe('font-size: 9px');
      expect(elt.css('font-size')).toBe('9px');
      expect(elt.contents()[1].textContent).toBe('18');
      size.set();
      expect(elt.attr('style')).toBe(undefined);
      expect(elt.css('font-size')).toBe('');
      return expect(elt.contents()[1].textContent).toBe('');
    });
    it('should have the given child contents', function() {
      let cont = elt.contents();
      let child = cont.last();
      expect(cont.length).toBe(3);
      expect(cont[0]).toEqual(jasmine.any(Text));
      expect(cont[0].textContent).toBe('hello world');
      expect(cont[1].tagName).toBe('SPAN');
      expect(cont[1].textContent).toBe('20');
      expect(cont.last().is('button')).toBe(true);
      return expect(cont.last().text()).toBe('click me');
    });
    return it('should not have special attrs set', function() {
      expect(elt.attr('init')).toBe(undefined);
      return expect(elt.attr('click')).toBe(undefined);
    });
  });

  return describe('SVG object creation', function() {
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

    it('should have the right tag', function() {
      expect(elt).toBeDefined();
      return expect(elt instanceof SVGRectElement).toBe(true);
    });
    it('should have the set attributes', function() {
      expect(elt.getAttribute('x')).toBe('10');
      return expect(elt.getAttribute('class')).toBe('shape');
    });
    return it('should have the given child contents', function() {
      let kids = elt.childNodes;
      expect(kids.length).toBe(1);
      return expect(kids[0] instanceof SVGElement).toBe(true);
    });
  });
});

describe('rxt of observable array', function() {
  let elt;
  let xs = (elt = null);
  beforeEach(function() {
    xs = rx.array([1,2,3]);
    return elt = rxt.tags.ul(xs.map(function(x) {
      if ((x % 2) === 0) {
        return `plain ${x}`;
      } else {
        return rxt.tags.li(`item ${x}`);
      }
    })
    );
  });
  it('should be initialized to the given contents', function() {
    let cont = elt.contents();
    expect(cont.length).toBe(3);
    expect(cont.eq(0).is('li')).toBe(true);
    expect(cont.eq(0).text()).toBe('item 1');
    expect(cont[1]).toEqual(jasmine.any(Text));
    expect(cont.eq(1).text()).toBe('plain 2');
    expect(cont.eq(2).is('li')).toBe(true);
    return expect(cont.eq(2).text()).toBe('item 3');
  });
  it('should update contents in response to array changes', function() {
    xs.splice(0, 3, 0, 1, 2);
    let cont = elt.contents();
    expect(cont[0]).toEqual(jasmine.any(Text));
    expect(cont.eq(0).text()).toBe('plain 0');
    expect(cont.eq(1).is('li')).toBe(true);
    expect(cont.eq(1).text()).toBe('item 1');
    expect(cont[2]).toEqual(jasmine.any(Text));
    return expect(cont.eq(2).text()).toBe('plain 2');
  });
  return it("should work with reactive map functions", function() {
    let x;
    let multiplierCell = rx.cell(1);
    let $ul = rxt.tags.ul(xs.map(f => rxt.tags.li(f * multiplierCell.get())));
    expect((() => {
      let result = [];
      for (x of Array.from($("li", $ul))) {         result.push($(x).text());
      }
      return result;
    })()).toEqual(["1", "2", "3"]);
    multiplierCell.set(10);
    return expect((() => {
      let result1 = [];
      for (x of Array.from($("li", $ul))) {         result1.push($(x).text());
      }
      return result1;
    })()).toEqual(["10", "20", "30"]);
  });
});

describe('flatten', function() {
  let i, mapped, xs, ys;
  let flattened = (mapped = (xs = (ys = (i = null))));
  beforeEach(function() {
    xs = rx.array(['b','c']);
    ys = rx.array(['E','F']);
    i = rx.cell('i');
    let zset = rx.set(['X', 'K', [], 'C', 'D', [new Set(['XKCD!'])]]);
    new Set([50]);
    flattened = rx.flatten([
      'A',
      xs.map(x => x.toUpperCase()),
      'D',
      ys.map(y => y),
      ['G','H'],
      bind(() => i.get().toUpperCase()),
      zset.all()
    ]);
    return mapped = flattened.map(x => x.toLowerCase());
  });
  it('should flatten and react to observables', function() {
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','G','H','I','X','K','C','D','XKCD!']);
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','g','h','i','x','k','c','d','xkcd!']);
    i.set('j');
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','G','H','J','X','K','C','D','XKCD!']);
    expect(mapped.all()).toEqual(['a','b','c','d','e','f','g','h','j','x','k','c','d','xkcd!']);
    ys.push('f');
    expect(flattened.all()).toEqual(['A','B','C','D','E','F','f','G','H','J','X','K','C','D','XKCD!']);
    return expect(mapped.all()).toEqual(['a','b','c','d','e','f','f','g','h','j','x','k','c','d','xkcd!']);
  });
  it('should not flatten jQuery objects (which are array-like)', function() {
    flattened = rx.flatten([
      $('body'),
      bind(() => $('<div/>'))
    ]);
    expect(flattened.at(0).is('body')).toBe(true);
    return expect(flattened.at(1).is('div')).toBe(true);
  });
  it('should remove undefineds/nulls (for convenient conditionals)', function() {
    flattened = rx.flatten([
      1,
      rx.cell(),
      undefined,
      [undefined],
      bind(() => undefined),
      rx.array([null]),
      2
    ]);
    return expect(flattened.all()).toEqual([1,2]);
  });
  return it('should flatten recursively', function() {
    flattened = rx.flatten([
      1,
      rx.cell(),
      rx.cell([rx.array([42]), [500, undefined, rx.set([800])], [null, new Set([null])]]),
      undefined,
      [undefined],
      bind(() => undefined),
      rx.array([null]),
      rx.array([
        rx.array(["ABC"]),
        rx.array([rx.array(["DEF"]), ["GHI"]]), [null], rx.array([[null]])]),
      "XYZ",
      2
    ]);
    return expect(snap(() => flattened.all())).toEqual([
      1, 42, 500, 800, "ABC", "DEF", "GHI", "XYZ", 2
    ]);
  });
});
describe('RawHtml', function() {
  let frag = null;
  beforeEach(() => frag = rxt.rawHtml('<em>hi</em>'));
  it('should support insertion of arbitrary HTML elements', function() {
    let $x = div({class: 'stuff'}, bind(() => [frag]));
    return expect($x.html()).toBe('<em>hi</em>');
  });
  return it('should only be supported if containing single element', function() {
    frag = rxt.rawHtml('<em>hi</em><em>ho</em>');
    expect(() => div({class: 'stuff'}, bind(() => frag))).toThrow();
    return expect(() => div({class: 'stuff'}, bind(() => rxt.rawHtml('')))).toThrow();
  });
});

describe('rxt', () =>
  it('should take as contents (arrays of) numbers, strings, elements, RawHtml, $, or null', () =>
    (() => {
      let result = [];
      for (var useArray of [false, true]) {
        let maybeArray = function(x) { if (useArray) { return [x]; } else { return x; } };
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
  it('should trigger for each changed attribute', function() {
    rxt.events.enabled = true;
    let handler = jasmine.createSpy();
    rx.autoSub(rxt.events.onElementAttrsChanged, handler);

    let stateCell = rx.cell("safe");
    let offsetCell = rx.cell(0);
    let $div = rxt.tags.div({
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
    return expect(handler).toHaveBeenCalledWith({$element: $div, attr: "style"});
  })
 );

describe('onElementChildrenChanged', function() {
  it("should work for reactive array body", function() {
    rxt.events.enabled = true;
    let handler = jasmine.createSpy();
    rx.autoSub(rxt.events.onElementChildrenChanged, handler);

    let items = rx.array([{name: "Chicken feet", price: 10}]);

    let $ul = rxt.tags.ul(items.map(item => rxt.tags.li(item)));

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
    return expect(handler.calls.first().args[0].removed.length).toBe(2);
  });

  return it("should work with reactive map function", function() {
    rxt.events.enabled = true;
    let handler = jasmine.createSpy();
    rx.autoSub(rxt.events.onElementChildrenChanged, handler);

    let onSaleCell = rx.cell(false);
    let items = rx.array([{name: "Chicken feet", price: 10}, {name: "buns", price: 5}]);

    let $ul = rxt.tags.ul(items.map(item => rxt.tags.li(onSaleCell.get() ? item.price * 0.1 : item.price))
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
    return expect(handler.calls.mostRecent().args[0].added[0]).toBe($("li", $ul)[0]);
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
    ["rx.ObsSet", rx.bind(() => [42, 45, 42]).toSet()]
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
  it('should fail on unrecognizable arguments', () => {
    expect(() => rxt.normalizeTagArgs("abc", "def")).toThrow();
    expect(() => rxt.normalizeTagArgs({}, new Map())).toThrow();
  })
});
