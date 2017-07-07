import $ from 'jquery';
import 'es5-shim';
import 'es6-shim';
import _ from 'underscore';
import * as rx from 'bobtail-rx';

let mktag, radio;
let prop, tag;
$.fn.rx = function(prop) {
  let map = this.data('rx-map');
  if ((map == null)) { this.data('rx-map', (map = Object.create(null))); }
  if (prop in map) { return map[prop]; }
  return map[prop] =
    (() => { switch (prop) {
      case 'focused':
        let focused = rx.cell(this.is(':focus'));
        this.focus(() => focused.set(true));
        this.blur(() => focused.set(false));
        return focused;
      case 'val':
        let val = rx.cell(this.val());
        this.change(() => val.set(this.val()));
        this.on('input', () => val.set(this.val()));
        return val;
      case 'checked':
        let checked = rx.cell(this.is(':checked'));
        this.change(() => checked.set(this.is(':checked')));
        return checked;
      default:
        throw new Error('Unknown reactive property type');
    } })();
};

//
// reactive template DSL
//

let prepContents = function(contents) {
  if (contents instanceof rx.ObsCell || contents instanceof rx.ObsArray || _.isArray(contents)) {
    contents = rx.flatten(contents);
  }
  return contents;
};

let events = {};
events.enabled = false;
events.onElementChildrenChanged = new rx.Ev();
events.onElementAttrsChanged = new rx.Ev();

class RawHtml {
  constructor(html) {
    this.html = html;
  }
}

// jQuery events are special attrs, along with `init`

let DOMEvents = ["blur", "change", "click", "dblclick", "error", "focus", "focusin",
  "focusout", "hover", "keydown", "keypress", "keyup", "load", "mousedown",
  "mouseenter", "mouseleave", "mousemove", "mouseout", "mouseover", "mouseup",
  "ready", "resize", "scroll", "select", "submit", "toggle", "unload"];

let svg_events = ["click"];

let specialAttrs = {
  init(elt, fn) { return fn.call(elt); }
};

for (let ev of Array.from(DOMEvents)) {
  (ev =>
    specialAttrs[ev] = function(elt, fn) {
      if (elt instanceof SVGElement && Array.from(svg_events).includes(ev)) {
        return elt.addEventListener(ev, fn);
      } else {
        return elt[ev](e => fn.call(elt, e));
      }
    }
  )(ev);
}

// attr vs prop:
// http://blog.jquery.com/2011/05/10/jquery-1-6-1-rc-1-released/
// http://api.jquery.com/prop/

let props = ['async', 'autofocus', 'checked', 'location', 'multiple', 'readOnly',
  'selected', 'selectedIndex', 'tagName', 'nodeName', 'nodeType',
  'ownerDocument', 'defaultChecked', 'defaultSelected'];
let propSet = _.object((() => {
  let result = [];
  for (prop of Array.from(props)) {       result.push([prop, null]);
  }
  return result;
})());

let setProp = function(elt, prop, val) {
  if (elt instanceof SVGElement) {
    return elt.setAttribute(prop, val);
  } else if (prop === 'value') {
    return elt.val(val);
  } else if (prop in propSet) {
    return elt.prop(prop, val);
  } else {
    return elt.attr(prop, val);
  }
};

let setDynProp = function(elt, prop, val, xform) {
  if (xform == null) { xform = _.identity; }
  if (val instanceof rx.ObsCell) {
    return rx.autoSub(val.onSet, function(...args) {
      let [o,n] = Array.from(args[0]);
      setProp(elt, prop, xform(n));
      if (events.enabled) {
        return events.onElementAttrsChanged.pub({$element: elt, attr: prop});
      }
  });
  } else {
    return setProp(elt, prop, xform(val));
  }
};

// arguments to a tag may be:
//   ()
//   (attrs: Object)
//   (contents: Contents)
//   (attrs: Object, contents: Contents)
// where Contents is:
//   string | number | Element | RawHtml | $ | Array | ObsCell | ObsArray
let normalizeTagArgs = function(arg1, arg2) {
  if ((arg1 == null) && (arg2 == null)) {
    return [{}, null];
  } else if (arg1 instanceof Object && (arg2 != null)) {
    return [arg1, arg2];
  } else if (((arg2 == null) &&
      _.isString(arg1)) ||
      _.isNumber(arg1) ||
      arg1 instanceof Element ||
      arg1 instanceof SVGElement ||
      arg1 instanceof RawHtml ||
      arg1 instanceof $ ||
      _.isArray(arg1) ||
      arg1 instanceof rx.ObsCell ||
      arg1 instanceof rx.ObsArray ||
      arg1 instanceof rx.ObsSet) {
    return [{}, arg1];
  } else {
    return [arg1, null];
  }
};

let toNodes = contents =>
  (() => {
    let result1 = [];
    for (let child of Array.from(contents)) {
      if (child != null) {
        if (_.isString(child) || _.isNumber(child)) {
          result1.push(document.createTextNode(child));
        } else if (child instanceof Element || child instanceof SVGElement) {
          result1.push(child);
        } else if (child instanceof RawHtml) {
          let parsed = $(child.html);
          if (parsed.length !== 1) { throw new Error('RawHtml must wrap a single element'); }
          result1.push(parsed[0]);
        } else if (child instanceof $) {
          if (child.length !== 1) { throw new Error('jQuery object must wrap a single element'); }
          result1.push(child[0]);
        } else {
          throw new Error(`Unknown element type in array: ${child.constructor.name} (must be string, number, Element, RawHtml, or jQuery objects)`);
        }
      } else {
        result1.push(undefined);
      }
    }
    return result1;
  })()
;

let updateContents = function(elt, contents) {
  let node;
  if (elt.html) { elt.html(''); }
  if ((contents == null)) {
    return;
  } else if (_.isArray(contents)) {
    let nodes = toNodes(contents);
    elt.append(nodes);
    if (false) { // this is super slow
      let hasWidth = function(node) {
        try { return ($(node).width() != null) !== 0; }
        catch (e) { return false; }
      };
      let covers = (() => {
        let result1 = [];
        for (node of Array.from(nodes != null ? nodes : [])) {
          if (hasWidth(node)) {
            let {left, top} = $(node).offset();
            result1.push($('<div/>').appendTo($('body').first())
              .addClass('updated-element').offset({top,left})
              .width($(node).width()).height($(node).height()));
          }
        }
        return result1;
      })();
      setTimeout((() => Array.from(covers).map((cover) => $(cover).remove())), 2000);
    }
    return nodes;
  } else if (_.isString(contents) || _.isNumber(contents) || contents instanceof Element ||
      contents instanceof SVGElement || contents instanceof RawHtml || contents instanceof $) {
    return updateContents(elt, [contents]);
  } else {
    throw new Error(`Unknown type for element contents: ${contents.constructor.name} (accepted types: string, number, Element, RawHtml, jQuery object of single element, or array of the aforementioned)`);
  }
};

mktag = tag =>
  function(arg1, arg2) {
    let [attrs, contents] = Array.from(normalizeTagArgs(arg1, arg2));
    contents = prepContents(contents);

    let elt = $(`<${tag}/>`);
    let object = _.omit(attrs, _.keys(specialAttrs));
    for (let name in object) {
      let value = object[name];
      setDynProp(elt, name, value);
    }
    if (contents != null) {
      if (contents instanceof rx.ObsArray) {
        rx.autoSub(contents.indexed().onChangeCells, function(...args) {
          let [index, removed, added] = Array.from(args[0]);
          elt.contents().slice(index, index + removed.length).remove();
          let toAdd = toNodes(added.map(function(...args1) { let cell, icell; [cell, icell] = Array.from(args1[0]); return rx.snap(() => cell.get()); }));
          if (index === elt.contents().length) {
            elt.append(toAdd);
          } else {
            elt.contents().eq(index).before(toAdd);
          }
          if (events.enabled && (removed.length || toAdd.length)) {
            events.onElementChildrenChanged.pub({
              $element: elt,
              type: "childrenUpdated",
              added: toAdd,
              removed: toNodes(removed.map(cell => rx.snap(() => cell.get())))
            });
          }
          return (() => {
            let result1 = [];
            for (let [cell, icell] of Array.from(added)) {
              result1.push(((cell, icell) =>
                rx.autoSub(cell.onSet, rx.skipFirst(function(...args1) {
                  let [old, val] = Array.from(args1[0]);
                  let ival = rx.snap(() => icell.get());
                  toAdd = toNodes([val]);
                  elt.contents().eq(ival).replaceWith(toAdd);
                  if (events.enabled) {
                    return events.onElementChildrenChanged.pub({
                      $element: elt, type: "childrenUpdated", updated: toAdd
                    });
                  }}))
              )(cell, icell));
            }
            return result1;
          })();
      });
      } else {
        updateContents(elt, contents);
      }
    }
    for (let key in attrs) {
      if (key in specialAttrs) {
        specialAttrs[key](elt, attrs[key], attrs, contents);
      }
    }
    return elt;
  };

// From <https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/HTML5/HTML5_element_list>
//
// Extract with:
//
//     "['"+document.body.innerText.match(/<.*?>/g).map(function(x){return x.substring(1, x.length-1);}).join("', '")+"']";

let tags = ['html', 'head', 'title', 'base', 'link', 'meta', 'style', 'script',
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
  'menuitem', 'menu'];

// From <https://developer.mozilla.org/en-US/docs/Web/SVG/Element>
let svg_tags = ['a', 'altglyph', 'altglyphdef', 'altglyphitem', 'animate',
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
  'textpath', 'title', 'tref', 'tspan', 'use', 'view', 'vkern'];

let updateSVGContents = function(elt, contents) {
  while (elt.firstChild) { elt.removeChild(elt.firstChild); }
  if (_.isArray(contents)) {
    let toAdd = toNodes(contents);
    return Array.from(toAdd).map((node) => (elt.appendChild(node)));
  } else if (_.isString(contents) || contents instanceof SVGElement) {
    return updateSVGContents(elt, [contents]);
  } else {
    console.error('updateSVGContents', elt, contents);
    throw `Must wrap contents ${contents} as array or string`;
  }
};

let svg_mktag = tag =>
  function(arg1, arg2) {
    let [attrs, contents] = Array.from(normalizeTagArgs(arg1, arg2));

    let elt = document.createElementNS('http://www.w3.org/2000/svg', tag);
    let object = _.omit(attrs, _.keys(specialAttrs));
    for (let name in object) {
      let value = object[name];
      setDynProp(elt, name, value);
    }

    if (contents != null) {
      if (contents instanceof rx.ObsArray) {
        contents.onChange.sub(function(...args) {
          let node;
          let [index, removed, added] = Array.from(args[0]);
          for (let i = 0, end = removed.length, asc = 0 <= end; asc ? i < end : i > end; asc ? i++ : i--) { elt.removeChild(elt.childNodes[index]); }
          let toAdd = toNodes(added);
          if (index === elt.childNodes.length) {
            return (() => {
              let result1 = [];
              for (node of Array.from(toAdd)) {                   result1.push((elt.appendChild(node)));
              }
              return result1;
            })();
          } else {
            return (() => {
              let result2 = [];
              for (node of Array.from(toAdd)) {                   result2.push((elt.childNodes[index].insertBefore(node)));
              }
              return result2;
            })();
          }
        });
      } else if (contents instanceof rx.ObsCell) {
        contents.onSet.sub(function(...args) { let [old, val] = Array.from(args[0]); return updateSVGContents(elt, val); });
      } else {
        updateSVGContents(elt, contents);
      }
    }

    for (let key in attrs) {
      if (key in specialAttrs) {
        specialAttrs[key](elt, attrs[key], attrs, contents);
      }
    }
    return elt;
  };

tags = _.object(tags.map(tag => [tag, mktag(tag)]));
let {input} = tags;

let _input = (type, opts) => input(_.extend({type}, opts));
input.color = opts => _input('color', opts);
input.date = opts => _input('date', opts);
input.datetime = opts => _input('datetime', opts);
input.datetimeLocal = opts => _input('datetime-local', opts);
input.email = opts => _input('email', opts);
input.file = opts => _input('file', opts);
input.hidden = opts => _input('hidden', opts);
input.image = opts => _input('image', opts);
input.month = opts => _input('month', opts);
input.number = opts => _input('number', opts);
input.password = opts => _input('password', opts);
input.range = opts => _input('range', opts);
input.reset = opts => _input('reset', opts);
input.search = opts => _input('search', opts);
input.submit = opts => _input('submit', opts);
input.tel = opts => _input('tel', opts);
input.text = opts => _input('text', opts);
input.time = opts => _input('time', opts);
input.url = opts => _input('url', opts);
input.week = opts => _input('week', opts);

let swapChecked = function($input) {
  /*
  Swaps $input.prop so that, whenever $input.prop("checked", ...) is called to set whether $input
  is checked, we also update the content of $input.rx("checked") with the same.
  */
  $input._oldProp = $input.prop;
  $input.prop = function(...args) {
    let res = $input._oldProp(...Array.from(args || []));
    if ((args.length > 1) && (args[0] === "checked")) {
      $input.rx("checked").set($input.prop("checked"));
    }
    return res;
  };
  return $input;
};

input.checkbox = opts =>
  /*
  A checkbox with a default property `data-unchecked-value` of "false".  This is so that if you
  use $.serializeJSON() to read the value of this checkbox in a form, the value will be false
  if it is unchecked.
  */
  swapChecked(input(_.extend({type: "checkbox"}, opts)))
;

input.radio = (radio = opts => swapChecked(input(_.extend({type: "radio"}, opts))));

svg_tags = _.object(svg_tags.map(svg_tag => [svg_tag, svg_mktag(svg_tag)]));

let rawHtml = html => new RawHtml(html);
let specialChar = function(code, tag) { if (tag == null) { tag = 'span'; } return rawHtml(`<${tag}>&${code};</${tag}>`); };
let unicodeChar = function(code, tag) { if (tag == null) { tag = 'span'; } return rawHtml(`<${tag}>\\u${code};</${tag}>`); };
//
// rxt utilities
//

// a little underscore-string inlining
let trim = $.trim;

let dasherize = str=> trim(str).replace(/([A-Z])/g, '-$1').replace(/[-_\s]+/g, '-').toLowerCase();

specialAttrs.style = function(elt, value) {
  let isCell = value instanceof rx.ObsCell;
  return rx.autoSub(rx.cast(value).onSet, function(...args) {
    let [o,n] = Array.from(args[0]);
    if ((n == null) || _.isString(n)) {
      setProp(elt, 'style', n);
    } else {
      elt.removeAttr('style').css(n);
    }
    if (isCell && events.enabled) {
      return events.onElementAttrsChanged.pub({$element: elt, attr: "style"});
    }
});
};

let smushClasses = xs => _(xs).chain().flatten().compact().value().join(' ').replace(/\s+/, ' ').trim();

specialAttrs.class = (elt, value) =>
  setDynProp(elt, 'class', value, function(val) {
    if (_.isString(val)) { return val; } else { return smushClasses(val); }
  })
;

export * from 'bobtail-rx';
export let rxt = {
  events, RawHtml, specialAttrs, mktag, svg_mktag, tags, svg_tags, rawHtml, specialChar, unicodeChar,
  trim, dasherize, smushClasses
};