import $ from "jquery";
import "es5-shim";
import "es6-shim";
import _ from "underscore";
import * as rx from "bobtail-rx";

let mktag;
$.fn.rx = function(prop) {
  let map = this.data("rx-map");
  if ((map == null)) {
    this.data("rx-map", (map = Object.create(null)));
  }
  if (!(prop in map)) {
    switch (prop) {
    case "focused": {
      let focused = rx.cell(this.is(":focus"));
      this.focus(() => focused.set(true));
      this.blur(() => focused.set(false));
      map[prop] = focused;
      break;
    }
    case "val": {
      let val = rx.cell(this.val());
      this.change(() => val.set(this.val()));
      this.on("input", () => val.set(this.val()));
      map[prop] = val;
      break;
    }
    case "checked": {
      let checked = rx.cell(this.is(":checked"));
      this.change(() => checked.set(this.is(":checked")));
      map[prop] = checked;
      break;
    }
    default: {
      throw new Error("Unknown reactive property type");
    }
    }
  }
  return map[prop];
};

//
// reactive template DSL
//
const autoFuncBind = (x) => _.isFunction(x) ? rx.bind(x) : x;

const flattenWeb = (x) => rx.flatten(x, rxtFlattenHelper);

const rxtFlattenHelper = x =>
  _.isFunction(x)
    ? rxtFlattenHelper(x())
    : rx.flattenHelper(x, rxtFlattenHelper);

const prepContents = function(contents) {
  if (
    contents instanceof rx.ObsCell ||
    contents instanceof rx.ObsArray ||
    _.isArray(contents) ||
    _.isFunction(contents)
  ) {
    contents = flattenWeb(contents);
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
let smushClasses = xs => _(xs).chain().flatten().compact().value().join(" ").replace(/\s+/, " ").trim();

let specialAttrs = {
  init(elt, fn) { return fn.call(elt); },
  style (elt, value) {
    value = autoFuncBind(value);
    let isCell = value instanceof rx.ObsCell;
    return rx.autoSub(rx.cast(value).onSet, ([o, n]) => {
      if ((n == null) || _.isString(n)) {
        setProp(elt, "style", n);
      } else {
        elt.removeAttr("style").css(n);
      }
      if (isCell && events.enabled) {
        return events.onElementAttrsChanged.pub({$element: elt, attr: "style"});
      }
    });
  },
  class (elt, value) {
    return setDynProp(elt, "class", value, function(val) {
      if (_.isString(val)) { return val; } else { return smushClasses(val); }
    });
  }
};

for (let ev of DOMEvents) {
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

// a little underscore-string inlining
let trim = $.trim;

let dasherize = str=> trim(str).replace(/([A-Z])/g, "-$1").replace(/[-_\s]+/g, "-").toLowerCase();

// attr vs prop:
// http://blog.jquery.com/2011/05/10/jquery-1-6-1-rc-1-released/
// http://api.jquery.com/prop/

let props = ["async", "autofocus", "checked", "location", "multiple", "readOnly",
  "selected", "selectedIndex", "tagName", "nodeName", "nodeType",
  "ownerDocument", "defaultChecked", "defaultSelected"
];
let propSet = _.object(props.map(prop => [prop, null]));

let setProp = function(elt, prop, val) {
  if (elt instanceof SVGElement) {
    return elt.setAttribute(prop, val);
  } else if (prop === "value") {
    return elt.val(val);
  } else if (prop in propSet) {
    return elt.prop(prop, val);
  } else {
    return elt.attr(prop, val);
  }
};

let setDynProp = function(elt, prop, val, xform) {
  if (xform == null) { xform = _.identity; }
  val = autoFuncBind(val);
  if (val instanceof rx.ObsCell) {
    return rx.autoSub(val.onSet, function([o, n]) {
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
let validContents = contents => (
  _.isString(contents) ||
  _.isNumber(contents) ||
  _.isArray(contents) ||
  _.isBoolean(contents) ||
  _.isFunction(contents) ||
  contents instanceof Element ||
  contents instanceof SVGElement ||
  contents instanceof RawHtml ||
  contents instanceof $ ||
  contents instanceof rx.ObsCell ||
  contents instanceof rx.ObsArray ||
  contents instanceof rx.ObsSet
);

let normalizeTagArgs = function(...args) {
  // while not strictly necessary, a great deal of the special-casing in this function is provided
  // to ensure exact backwards compatibility.
  // @TODO: Prior to the 3.0.0 release, this should be simplified.
  args = args.filter(a => a != null);
  let first = _.first(args);
  let rest = args.slice(1);
  if (first == null && !rest.length) {
    return [{}, null];
  } else if (validContents(first)) {
    if(args.length > 1) {
      return [{}, args];
    }
    else {
      return [{}, first];
    }
  } else {
    if (rest.length === 0) {
      return [first, null];
    }
    else if(rest.length === 1) {
      return [first, _.first(rest)];
    }
    return [first, rest];
  }
};

let toNodes = contents => {
  let result1 = [];
  for (let child of Array.from(contents)) {
    if (child != null) {
      if (_.isString(child) || _.isNumber(child)) {
        result1.push(document.createTextNode(child));
      } else if (child instanceof Element || child instanceof SVGElement) {
        result1.push(child);
      } else if (child instanceof RawHtml) {
        let parsed = $(child.html);
        if (parsed.length !== 1) { throw new Error("RawHtml must wrap a single element"); }
        result1.push(parsed[0]);
      } else if (child instanceof $) {
        if (child.length !== 1) { throw new Error("jQuery object must wrap a single element"); }
        result1.push(child[0]);
      } else {
        throw new Error(
          `Unknown element type in array: ${child.constructor.name} (must be string, number, function, 
Element, RawHtml, or jQuery objects)`
        );
      }
    } else {
      result1.push(undefined);
    }
  }
  return result1;
};

let updateContents = function(elt, contents) {
  if (elt.html) { elt.html(""); }
  if ((contents == null)) {
    return;
  } else if (_.isArray(contents)) {
    let nodes = toNodes(contents);
    elt.append(nodes);
    return nodes;
  } else if (
    _.isString(contents) ||
    _.isNumber(contents) ||
    _.isBoolean(contents) ||
      contents instanceof Element ||
      contents instanceof SVGElement ||
      contents instanceof RawHtml ||
      contents instanceof $
  ) {
    return updateContents(elt, [contents]);
  } else {
    throw new Error(
      `Unknown type for element contents: ${contents.constructor.name} 
(accepted types: string, number, Element, RawHtml, jQuery object of single element, 
or array of the aforementioned)`
    );
  }
};

mktag = tag =>
  function(...args) {
    let [attrs, contents] = Array.from(normalizeTagArgs(...args));
    contents = prepContents(contents);

    let elt = $(`<${tag}/>`);
    attrs = _.mapObject(attrs, (value, key) => {
      if(key in specialAttrs) return value;
      else return autoFuncBind(value);
    });
    let object = _.omit(attrs, _.keys(specialAttrs));
    for (let name in object) {
      let value = object[name];
      setDynProp(elt, name, value);
    }
    if (contents != null) {
      if (contents instanceof rx.ObsArray) {
        rx.autoSub(contents.indexed().onChangeCells, function([index, removed, added]) {
          elt.contents().slice(index, index + removed.length).remove();
          let toAdd = toNodes(added.map(([cell, icell]) => rx.snap(() => cell.get())));
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
                rx.autoSub(cell.onSet, rx.skipFirst(([old, val]) => {
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

let tags = ["html", "head", "title", "base", "link", "meta", "style", "script",
  "noscript", "body", "body", "section", "nav", "article", "aside", "h1", "h2",
  "h3", "h4", "h5", "h6", "h1", "h6", "header", "footer", "address", "main",
  "main", "p", "hr", "pre", "blockquote", "ol", "ul", "li", "dl", "dt", "dd",
  "dd", "figure", "figcaption", "div", "a", "em", "strong", "small", "s",
  "cite", "q", "dfn", "abbr", "data", "time", "code", "var", "samp", "kbd",
  "sub", "sup", "i", "b", "u", "mark", "ruby", "rt", "rp", "bdi", "bdo",
  "span", "br", "wbr", "ins", "del", "img", "iframe", "embed", "object",
  "param", "object", "video", "audio", "source", "video", "audio", "track",
  "video", "audio", "canvas", "map", "area", "area", "map", "svg", "math",
  "table", "caption", "colgroup", "col", "tbody", "thead", "tfoot", "tr", "td",
  "th", "form", "fieldset", "legend", "fieldset", "label", "input", "button",
  "select", "datalist", "optgroup", "option", "select", "datalist", "textarea",
  "keygen", "output", "progress", "meter", "details", "summary", "details",
  "menuitem", "menu"];

// From <https://developer.mozilla.org/en-US/docs/Web/SVG/Element>
let svg_tags = ["a", "altglyph", "altglyphdef", "altglyphitem", "animate",
  "animatecolor", "animatemotion", "animatetransform", "circle", "clippath",
  "color-profile", "cursor", "defs", "desc", "ellipse", "feblend",
  "fecolormatrix", "fecomponenttransfer", "fecomposite", "feconvolvematrix",
  "fediffuselighting", "fedisplacementmap", "fedistantlight", "feflood",
  "fefunca", "fefuncb", "fefuncg", "fefuncr", "fegaussianblur", "feimage",
  "femerge", "femergenode", "femorphology", "feoffset", "fepointlight",
  "fespecularlighting", "fespotlight", "fetile", "feturbulence", "filter",
  "font", "font-face", "font-face-format", "font-face-name", "font-face-src",
  "font-face-uri", "foreignobject", "g", "glyph", "glyphref", "hkern", "image",
  "line", "lineargradient", "marker", "mask", "metadata", "missing-glyph",
  "mpath", "path", "pattern", "polygon", "polyline", "radialgradient", "rect",
  "script", "set", "stop", "style", "svg", "switch", "symbol", "text",
  "textpath", "title", "tref", "tspan", "use", "view", "vkern"];

let updateSVGContents = function(elt, contents) {
  while (elt.firstChild) { elt.removeChild(elt.firstChild); }
  if (_.isArray(contents)) {
    let toAdd = toNodes(contents);
    return Array.from(toAdd).map((node) => (elt.appendChild(node)));
  } else if (_.isString(contents) || contents instanceof SVGElement) {
    return updateSVGContents(elt, [contents]);
  } else {
    /*eslint-disable*/
    console.error("updateSVGContents", elt, contents);
    /*eslint-enable*/
    throw `Must wrap contents ${contents} as array or string`;
  }
};

let svg_mktag = tag =>
  function(...args) {
    let [attrs, contents] = Array.from(normalizeTagArgs(...args));

    let elt = document.createElementNS("http://www.w3.org/2000/svg", tag);
    let object = _.omit(attrs, _.keys(specialAttrs));
    for (let name in object) {
      let value = object[name];
      setDynProp(elt, name, value);
    }

    if(_.isFunction(contents)) {
      contents = rx.bind(contents);
    }

    if (contents != null) {
      if (contents instanceof rx.ObsArray) {
        contents.onChange.sub(function(...args) {
          let [index, removed, added] = Array.from(args[0]);
          for (let i = 0, end = removed.length, asc = 0 <= end; asc ? i < end : i > end; asc ? i++ : i--) { elt.removeChild(elt.childNodes[index]); }
          let toAdd = toNodes(added);
          if (index === elt.childNodes.length) {
            return toAdd.map((node) => elt.appendChild(node));
          } else {
            return toAdd.map(node => elt.childNodes[index].insertBefore(node));
          }
        });
      } else if (contents instanceof rx.ObsCell) {
        contents.onSet.sub(([old, val]) => updateSVGContents(elt, val));
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
input.color = opts => _input("color", opts);
input.date = opts => _input("date", opts);
input.datetime = opts => _input("datetime", opts);
input.datetimeLocal = opts => _input("datetime-local", opts);
input.email = opts => _input("email", opts);
input.file = opts => _input("file", opts);
input.hidden = opts => _input("hidden", opts);
input.image = opts => _input("image", opts);
input.month = opts => _input("month", opts);
input.number = opts => _input("number", opts);
input.password = opts => _input("password", opts);
input.range = opts => _input("range", opts);
input.reset = opts => _input("reset", opts);
input.search = opts => _input("search", opts);
input.submit = opts => _input("submit", opts);
input.tel = opts => _input("tel", opts);
input.text = opts => _input("text", opts);
input.time = opts => _input("time", opts);
input.url = opts => _input("url", opts);
input.week = opts => _input("week", opts);

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

input.radio = (opts => swapChecked(input(_.extend({type: "radio"}, opts))));

svg_tags = _.object(svg_tags.map(svg_tag => [svg_tag, svg_mktag(svg_tag)]));

let rawHtml = html => new RawHtml(html);
let specialChar = function(code, tag) { if (tag == null) { tag = "span"; } return rawHtml(`<${tag}>&${code};</${tag}>`); };
let unicodeChar = function(code, tag) { if (tag == null) { tag = "span"; } return rawHtml(`<${tag}>\\u${code};</${tag}>`); };
//
// rxt utilities
//

export * from "bobtail-rx";
export let rxt = {
  events, RawHtml, specialAttrs, mktag, svg_mktag, tags, svg_tags, rawHtml, specialChar, unicodeChar,
  trim, dasherize, smushClasses, normalizeTagArgs, flattenWeb, rxtFlattenHelper
};