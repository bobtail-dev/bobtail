(function (global, factory) {
  if (typeof define === "function" && define.amd) {
    define('bobtail', ['exports', 'bobtail-rx', 'jquery', 'underscore', 'es5-shim', 'es6-shim'], factory);
  } else if (typeof exports !== "undefined") {
    factory(exports, require('bobtail-rx'), require('jquery'), require('underscore'), require('es5-shim'), require('es6-shim'));
  } else {
    var mod = {
      exports: {}
    };
    factory(mod.exports, global.rx, global.$, global._, global.es5Shim, global.es6Shim);
    global.rx = mod.exports;
  }
})(this, function (exports, _bobtailRx, _jquery, _underscore) {
  'use strict';

  Object.defineProperty(exports, "__esModule", {
    value: true
  });
  exports.rxt = undefined;
  Object.keys(_bobtailRx).forEach(function (key) {
    if (key === "default" || key === "__esModule") return;
    Object.defineProperty(exports, key, {
      enumerable: true,
      get: function () {
        return _bobtailRx[key];
      }
    });
  });

  var _jquery2 = _interopRequireDefault(_jquery);

  var _underscore2 = _interopRequireDefault(_underscore);

  var rx = _interopRequireWildcard(_bobtailRx);

  function _interopRequireWildcard(obj) {
    if (obj && obj.__esModule) {
      return obj;
    } else {
      var newObj = {};

      if (obj != null) {
        for (var key in obj) {
          if (Object.prototype.hasOwnProperty.call(obj, key)) newObj[key] = obj[key];
        }
      }

      newObj.default = obj;
      return newObj;
    }
  }

  function _interopRequireDefault(obj) {
    return obj && obj.__esModule ? obj : {
      default: obj
    };
  }

  function _toConsumableArray(arr) {
    if (Array.isArray(arr)) {
      for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {
        arr2[i] = arr[i];
      }

      return arr2;
    } else {
      return Array.from(arr);
    }
  }

  var _slicedToArray = function () {
    function sliceIterator(arr, i) {
      var _arr = [];
      var _n = true;
      var _d = false;
      var _e = undefined;

      try {
        for (var _i = arr[Symbol.iterator](), _s; !(_n = (_s = _i.next()).done); _n = true) {
          _arr.push(_s.value);

          if (i && _arr.length === i) break;
        }
      } catch (err) {
        _d = true;
        _e = err;
      } finally {
        try {
          if (!_n && _i["return"]) _i["return"]();
        } finally {
          if (_d) throw _e;
        }
      }

      return _arr;
    }

    return function (arr, i) {
      if (Array.isArray(arr)) {
        return arr;
      } else if (Symbol.iterator in Object(arr)) {
        return sliceIterator(arr, i);
      } else {
        throw new TypeError("Invalid attempt to destructure non-iterable instance");
      }
    };
  }();

  function _classCallCheck(instance, Constructor) {
    if (!(instance instanceof Constructor)) {
      throw new TypeError("Cannot call a class as a function");
    }
  }

  var mktag = void 0,
      radio = void 0;
  var prop = void 0,
      tag = void 0;
  _jquery2.default.fn.rx = function (prop) {
    var _this = this;

    var map = this.data('rx-map');
    if (map == null) {
      this.data('rx-map', map = Object.create(null));
    }
    if (prop in map) {
      return map[prop];
    }
    return map[prop] = function () {
      switch (prop) {
        case 'focused':
          var focused = rx.cell(_this.is(':focus'));
          _this.focus(function () {
            return focused.set(true);
          });
          _this.blur(function () {
            return focused.set(false);
          });
          return focused;
        case 'val':
          var val = rx.cell(_this.val());
          _this.change(function () {
            return val.set(_this.val());
          });
          _this.on('input', function () {
            return val.set(_this.val());
          });
          return val;
        case 'checked':
          var checked = rx.cell(_this.is(':checked'));
          _this.change(function () {
            return checked.set(_this.is(':checked'));
          });
          return checked;
        default:
          throw new Error('Unknown reactive property type');
      }
    }();
  };

  //
  // reactive template DSL
  //

  var prepContents = function prepContents(contents) {
    if (contents instanceof rx.ObsCell || contents instanceof rx.ObsArray || _underscore2.default.isArray(contents)) {
      contents = rx.flatten(contents);
    }
    return contents;
  };

  var events = {};
  events.enabled = false;
  events.onElementChildrenChanged = new rx.Ev();
  events.onElementAttrsChanged = new rx.Ev();

  var RawHtml = function RawHtml(html) {
    _classCallCheck(this, RawHtml);

    this.html = html;
  };

  // jQuery events are special attrs, along with `init`

  var DOMEvents = ["blur", "change", "click", "dblclick", "error", "focus", "focusin", "focusout", "hover", "keydown", "keypress", "keyup", "load", "mousedown", "mouseenter", "mouseleave", "mousemove", "mouseout", "mouseover", "mouseup", "ready", "resize", "scroll", "select", "submit", "toggle", "unload"];

  var svg_events = ["click"];

  var specialAttrs = {
    init: function init(elt, fn) {
      return fn.call(elt);
    }
  };

  var _iteratorNormalCompletion = true;
  var _didIteratorError = false;
  var _iteratorError = undefined;

  try {
    for (var _iterator = Array.from(DOMEvents)[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true) {
      var ev = _step.value;

      (function (ev) {
        return specialAttrs[ev] = function (elt, fn) {
          if (elt instanceof SVGElement && Array.from(svg_events).includes(ev)) {
            return elt.addEventListener(ev, fn);
          } else {
            return elt[ev](function (e) {
              return fn.call(elt, e);
            });
          }
        };
      })(ev);
    }

    // attr vs prop:
    // http://blog.jquery.com/2011/05/10/jquery-1-6-1-rc-1-released/
    // http://api.jquery.com/prop/
  } catch (err) {
    _didIteratorError = true;
    _iteratorError = err;
  } finally {
    try {
      if (!_iteratorNormalCompletion && _iterator.return) {
        _iterator.return();
      }
    } finally {
      if (_didIteratorError) {
        throw _iteratorError;
      }
    }
  }

  var props = ['async', 'autofocus', 'checked', 'location', 'multiple', 'readOnly', 'selected', 'selectedIndex', 'tagName', 'nodeName', 'nodeType', 'ownerDocument', 'defaultChecked', 'defaultSelected'];
  var propSet = _underscore2.default.object(function () {
    var result = [];
    var _iteratorNormalCompletion2 = true;
    var _didIteratorError2 = false;
    var _iteratorError2 = undefined;

    try {
      for (var _iterator2 = Array.from(props)[Symbol.iterator](), _step2; !(_iteratorNormalCompletion2 = (_step2 = _iterator2.next()).done); _iteratorNormalCompletion2 = true) {
        prop = _step2.value;
        result.push([prop, null]);
      }
    } catch (err) {
      _didIteratorError2 = true;
      _iteratorError2 = err;
    } finally {
      try {
        if (!_iteratorNormalCompletion2 && _iterator2.return) {
          _iterator2.return();
        }
      } finally {
        if (_didIteratorError2) {
          throw _iteratorError2;
        }
      }
    }

    return result;
  }());

  var setProp = function setProp(elt, prop, val) {
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

  var setDynProp = function setDynProp(elt, prop, val, xform) {
    if (xform == null) {
      xform = _underscore2.default.identity;
    }
    if (val instanceof rx.ObsCell) {
      return rx.autoSub(val.onSet, function () {
        var _Array$from = Array.from(arguments.length <= 0 ? undefined : arguments[0]),
            _Array$from2 = _slicedToArray(_Array$from, 2),
            o = _Array$from2[0],
            n = _Array$from2[1];

        setProp(elt, prop, xform(n));
        if (events.enabled) {
          return events.onElementAttrsChanged.pub({ $element: elt, attr: prop });
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
  var normalizeTagArgs = function normalizeTagArgs(arg1, arg2) {
    if (arg1 == null && arg2 == null) {
      return [{}, null];
    } else if (arg1 instanceof Object && arg2 != null) {
      return [arg1, arg2];
    } else if (arg2 == null && _underscore2.default.isString(arg1) || _underscore2.default.isNumber(arg1) || arg1 instanceof Element || arg1 instanceof SVGElement || arg1 instanceof RawHtml || arg1 instanceof _jquery2.default || _underscore2.default.isArray(arg1) || arg1 instanceof rx.ObsCell || arg1 instanceof rx.ObsArray || arg1 instanceof rx.ObsSet) {
      return [{}, arg1];
    } else {
      return [arg1, null];
    }
  };

  var toNodes = function toNodes(contents) {
    return function () {
      var result1 = [];
      var _iteratorNormalCompletion3 = true;
      var _didIteratorError3 = false;
      var _iteratorError3 = undefined;

      try {
        for (var _iterator3 = Array.from(contents)[Symbol.iterator](), _step3; !(_iteratorNormalCompletion3 = (_step3 = _iterator3.next()).done); _iteratorNormalCompletion3 = true) {
          var child = _step3.value;

          if (child != null) {
            if (_underscore2.default.isString(child) || _underscore2.default.isNumber(child)) {
              result1.push(document.createTextNode(child));
            } else if (child instanceof Element || child instanceof SVGElement) {
              result1.push(child);
            } else if (child instanceof RawHtml) {
              var parsed = (0, _jquery2.default)(child.html);
              if (parsed.length !== 1) {
                throw new Error('RawHtml must wrap a single element');
              }
              result1.push(parsed[0]);
            } else if (child instanceof _jquery2.default) {
              if (child.length !== 1) {
                throw new Error('jQuery object must wrap a single element');
              }
              result1.push(child[0]);
            } else {
              throw new Error('Unknown element type in array: ' + child.constructor.name + ' (must be string, number, Element, RawHtml, or jQuery objects)');
            }
          } else {
            result1.push(undefined);
          }
        }
      } catch (err) {
        _didIteratorError3 = true;
        _iteratorError3 = err;
      } finally {
        try {
          if (!_iteratorNormalCompletion3 && _iterator3.return) {
            _iterator3.return();
          }
        } finally {
          if (_didIteratorError3) {
            throw _iteratorError3;
          }
        }
      }

      return result1;
    }();
  };

  var updateContents = function updateContents(elt, contents) {
    var node = void 0;
    if (elt.html) {
      elt.html('');
    }
    if (contents == null) {
      return;
    } else if (_underscore2.default.isArray(contents)) {
      var nodes = toNodes(contents);
      elt.append(nodes);
      if (false) {
        // this is super slow
        var hasWidth = function hasWidth(node) {
          try {
            return (0, _jquery2.default)(node).width() != null !== 0;
          } catch (e) {
            return false;
          }
        };
        var covers = function () {
          var result1 = [];
          var _iteratorNormalCompletion4 = true;
          var _didIteratorError4 = false;
          var _iteratorError4 = undefined;

          try {
            for (var _iterator4 = Array.from(nodes != null ? nodes : [])[Symbol.iterator](), _step4; !(_iteratorNormalCompletion4 = (_step4 = _iterator4.next()).done); _iteratorNormalCompletion4 = true) {
              node = _step4.value;

              if (hasWidth(node)) {
                var _$$offset = (0, _jquery2.default)(node).offset(),
                    left = _$$offset.left,
                    top = _$$offset.top;

                result1.push((0, _jquery2.default)('<div/>').appendTo((0, _jquery2.default)('body').first()).addClass('updated-element').offset({ top: top, left: left }).width((0, _jquery2.default)(node).width()).height((0, _jquery2.default)(node).height()));
              }
            }
          } catch (err) {
            _didIteratorError4 = true;
            _iteratorError4 = err;
          } finally {
            try {
              if (!_iteratorNormalCompletion4 && _iterator4.return) {
                _iterator4.return();
              }
            } finally {
              if (_didIteratorError4) {
                throw _iteratorError4;
              }
            }
          }

          return result1;
        }();
        setTimeout(function () {
          return Array.from(covers).map(function (cover) {
            return (0, _jquery2.default)(cover).remove();
          });
        }, 2000);
      }
      return nodes;
    } else if (_underscore2.default.isString(contents) || _underscore2.default.isNumber(contents) || contents instanceof Element || contents instanceof SVGElement || contents instanceof RawHtml || contents instanceof _jquery2.default) {
      return updateContents(elt, [contents]);
    } else {
      throw new Error('Unknown type for element contents: ' + contents.constructor.name + ' (accepted types: string, number, Element, RawHtml, jQuery object of single element, or array of the aforementioned)');
    }
  };

  mktag = function mktag(tag) {
    return function (arg1, arg2) {
      var _Array$from3 = Array.from(normalizeTagArgs(arg1, arg2)),
          _Array$from4 = _slicedToArray(_Array$from3, 2),
          attrs = _Array$from4[0],
          contents = _Array$from4[1];

      contents = prepContents(contents);

      var elt = (0, _jquery2.default)('<' + tag + '/>');
      var object = _underscore2.default.omit(attrs, _underscore2.default.keys(specialAttrs));
      for (var name in object) {
        var value = object[name];
        setDynProp(elt, name, value);
      }
      if (contents != null) {
        if (contents instanceof rx.ObsArray) {
          rx.autoSub(contents.indexed().onChangeCells, function () {
            var _Array$from5 = Array.from(arguments.length <= 0 ? undefined : arguments[0]),
                _Array$from6 = _slicedToArray(_Array$from5, 3),
                index = _Array$from6[0],
                removed = _Array$from6[1],
                added = _Array$from6[2];

            elt.contents().slice(index, index + removed.length).remove();
            var toAdd = toNodes(added.map(function () {
              var cell = void 0,
                  icell = void 0;
              var _Array$from7 = Array.from(arguments.length <= 0 ? undefined : arguments[0]);

              var _Array$from8 = _slicedToArray(_Array$from7, 2);

              cell = _Array$from8[0];
              icell = _Array$from8[1];
              return rx.snap(function () {
                return cell.get();
              });
            }));
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
                removed: toNodes(removed.map(function (cell) {
                  return rx.snap(function () {
                    return cell.get();
                  });
                }))
              });
            }
            return function () {
              var result1 = [];
              var _iteratorNormalCompletion5 = true;
              var _didIteratorError5 = false;
              var _iteratorError5 = undefined;

              try {
                for (var _iterator5 = Array.from(added)[Symbol.iterator](), _step5; !(_iteratorNormalCompletion5 = (_step5 = _iterator5.next()).done); _iteratorNormalCompletion5 = true) {
                  var _step5$value = _slicedToArray(_step5.value, 2),
                      cell = _step5$value[0],
                      icell = _step5$value[1];

                  result1.push(function (cell, icell) {
                    return rx.autoSub(cell.onSet, rx.skipFirst(function () {
                      var _Array$from9 = Array.from(arguments.length <= 0 ? undefined : arguments[0]),
                          _Array$from10 = _slicedToArray(_Array$from9, 2),
                          old = _Array$from10[0],
                          val = _Array$from10[1];

                      var ival = rx.snap(function () {
                        return icell.get();
                      });
                      toAdd = toNodes([val]);
                      elt.contents().eq(ival).replaceWith(toAdd);
                      if (events.enabled) {
                        return events.onElementChildrenChanged.pub({
                          $element: elt, type: "childrenUpdated", updated: toAdd
                        });
                      }
                    }));
                  }(cell, icell));
                }
              } catch (err) {
                _didIteratorError5 = true;
                _iteratorError5 = err;
              } finally {
                try {
                  if (!_iteratorNormalCompletion5 && _iterator5.return) {
                    _iterator5.return();
                  }
                } finally {
                  if (_didIteratorError5) {
                    throw _iteratorError5;
                  }
                }
              }

              return result1;
            }();
          });
        } else {
          updateContents(elt, contents);
        }
      }
      for (var key in attrs) {
        if (key in specialAttrs) {
          specialAttrs[key](elt, attrs[key], attrs, contents);
        }
      }
      return elt;
    };
  };

  // From <https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/HTML5/HTML5_element_list>
  //
  // Extract with:
  //
  //     "['"+document.body.innerText.match(/<.*?>/g).map(function(x){return x.substring(1, x.length-1);}).join("', '")+"']";

  var tags = ['html', 'head', 'title', 'base', 'link', 'meta', 'style', 'script', 'noscript', 'body', 'body', 'section', 'nav', 'article', 'aside', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'h1', 'h6', 'header', 'footer', 'address', 'main', 'main', 'p', 'hr', 'pre', 'blockquote', 'ol', 'ul', 'li', 'dl', 'dt', 'dd', 'dd', 'figure', 'figcaption', 'div', 'a', 'em', 'strong', 'small', 's', 'cite', 'q', 'dfn', 'abbr', 'data', 'time', 'code', 'var', 'samp', 'kbd', 'sub', 'sup', 'i', 'b', 'u', 'mark', 'ruby', 'rt', 'rp', 'bdi', 'bdo', 'span', 'br', 'wbr', 'ins', 'del', 'img', 'iframe', 'embed', 'object', 'param', 'object', 'video', 'audio', 'source', 'video', 'audio', 'track', 'video', 'audio', 'canvas', 'map', 'area', 'area', 'map', 'svg', 'math', 'table', 'caption', 'colgroup', 'col', 'tbody', 'thead', 'tfoot', 'tr', 'td', 'th', 'form', 'fieldset', 'legend', 'fieldset', 'label', 'input', 'button', 'select', 'datalist', 'optgroup', 'option', 'select', 'datalist', 'textarea', 'keygen', 'output', 'progress', 'meter', 'details', 'summary', 'details', 'menuitem', 'menu'];

  // From <https://developer.mozilla.org/en-US/docs/Web/SVG/Element>
  var svg_tags = ['a', 'altglyph', 'altglyphdef', 'altglyphitem', 'animate', 'animatecolor', 'animatemotion', 'animatetransform', 'circle', 'clippath', 'color-profile', 'cursor', 'defs', 'desc', 'ellipse', 'feblend', 'fecolormatrix', 'fecomponenttransfer', 'fecomposite', 'feconvolvematrix', 'fediffuselighting', 'fedisplacementmap', 'fedistantlight', 'feflood', 'fefunca', 'fefuncb', 'fefuncg', 'fefuncr', 'fegaussianblur', 'feimage', 'femerge', 'femergenode', 'femorphology', 'feoffset', 'fepointlight', 'fespecularlighting', 'fespotlight', 'fetile', 'feturbulence', 'filter', 'font', 'font-face', 'font-face-format', 'font-face-name', 'font-face-src', 'font-face-uri', 'foreignobject', 'g', 'glyph', 'glyphref', 'hkern', 'image', 'line', 'lineargradient', 'marker', 'mask', 'metadata', 'missing-glyph', 'mpath', 'path', 'pattern', 'polygon', 'polyline', 'radialgradient', 'rect', 'script', 'set', 'stop', 'style', 'svg', 'switch', 'symbol', 'text', 'textpath', 'title', 'tref', 'tspan', 'use', 'view', 'vkern'];

  var updateSVGContents = function updateSVGContents(elt, contents) {
    while (elt.firstChild) {
      elt.removeChild(elt.firstChild);
    }
    if (_underscore2.default.isArray(contents)) {
      var toAdd = toNodes(contents);
      return Array.from(toAdd).map(function (node) {
        return elt.appendChild(node);
      });
    } else if (_underscore2.default.isString(contents) || contents instanceof SVGElement) {
      return updateSVGContents(elt, [contents]);
    } else {
      console.error('updateSVGContents', elt, contents);
      throw 'Must wrap contents ' + contents + ' as array or string';
    }
  };

  var svg_mktag = function svg_mktag(tag) {
    return function (arg1, arg2) {
      var _Array$from11 = Array.from(normalizeTagArgs(arg1, arg2)),
          _Array$from12 = _slicedToArray(_Array$from11, 2),
          attrs = _Array$from12[0],
          contents = _Array$from12[1];

      var elt = document.createElementNS('http://www.w3.org/2000/svg', tag);
      var object = _underscore2.default.omit(attrs, _underscore2.default.keys(specialAttrs));
      for (var name in object) {
        var value = object[name];
        setDynProp(elt, name, value);
      }

      if (contents != null) {
        if (contents instanceof rx.ObsArray) {
          contents.onChange.sub(function () {
            var node = void 0;

            var _Array$from13 = Array.from(arguments.length <= 0 ? undefined : arguments[0]),
                _Array$from14 = _slicedToArray(_Array$from13, 3),
                index = _Array$from14[0],
                removed = _Array$from14[1],
                added = _Array$from14[2];

            for (var i = 0, end = removed.length, asc = 0 <= end; asc ? i < end : i > end; asc ? i++ : i--) {
              elt.removeChild(elt.childNodes[index]);
            }
            var toAdd = toNodes(added);
            if (index === elt.childNodes.length) {
              return function () {
                var result1 = [];
                var _iteratorNormalCompletion6 = true;
                var _didIteratorError6 = false;
                var _iteratorError6 = undefined;

                try {
                  for (var _iterator6 = Array.from(toAdd)[Symbol.iterator](), _step6; !(_iteratorNormalCompletion6 = (_step6 = _iterator6.next()).done); _iteratorNormalCompletion6 = true) {
                    node = _step6.value;
                    result1.push(elt.appendChild(node));
                  }
                } catch (err) {
                  _didIteratorError6 = true;
                  _iteratorError6 = err;
                } finally {
                  try {
                    if (!_iteratorNormalCompletion6 && _iterator6.return) {
                      _iterator6.return();
                    }
                  } finally {
                    if (_didIteratorError6) {
                      throw _iteratorError6;
                    }
                  }
                }

                return result1;
              }();
            } else {
              return function () {
                var result2 = [];
                var _iteratorNormalCompletion7 = true;
                var _didIteratorError7 = false;
                var _iteratorError7 = undefined;

                try {
                  for (var _iterator7 = Array.from(toAdd)[Symbol.iterator](), _step7; !(_iteratorNormalCompletion7 = (_step7 = _iterator7.next()).done); _iteratorNormalCompletion7 = true) {
                    node = _step7.value;
                    result2.push(elt.childNodes[index].insertBefore(node));
                  }
                } catch (err) {
                  _didIteratorError7 = true;
                  _iteratorError7 = err;
                } finally {
                  try {
                    if (!_iteratorNormalCompletion7 && _iterator7.return) {
                      _iterator7.return();
                    }
                  } finally {
                    if (_didIteratorError7) {
                      throw _iteratorError7;
                    }
                  }
                }

                return result2;
              }();
            }
          });
        } else if (contents instanceof rx.ObsCell) {
          contents.onSet.sub(function () {
            var _Array$from15 = Array.from(arguments.length <= 0 ? undefined : arguments[0]),
                _Array$from16 = _slicedToArray(_Array$from15, 2),
                old = _Array$from16[0],
                val = _Array$from16[1];

            return updateSVGContents(elt, val);
          });
        } else {
          updateSVGContents(elt, contents);
        }
      }

      for (var key in attrs) {
        if (key in specialAttrs) {
          specialAttrs[key](elt, attrs[key], attrs, contents);
        }
      }
      return elt;
    };
  };

  tags = _underscore2.default.object(tags.map(function (tag) {
    return [tag, mktag(tag)];
  }));
  var _tags = tags,
      input = _tags.input;


  var _input = function _input(type, opts) {
    return input(_underscore2.default.extend({ type: type }, opts));
  };
  input.color = function (opts) {
    return _input('color', opts);
  };
  input.date = function (opts) {
    return _input('date', opts);
  };
  input.datetime = function (opts) {
    return _input('datetime', opts);
  };
  input.datetimeLocal = function (opts) {
    return _input('datetime-local', opts);
  };
  input.email = function (opts) {
    return _input('email', opts);
  };
  input.file = function (opts) {
    return _input('file', opts);
  };
  input.hidden = function (opts) {
    return _input('hidden', opts);
  };
  input.image = function (opts) {
    return _input('image', opts);
  };
  input.month = function (opts) {
    return _input('month', opts);
  };
  input.number = function (opts) {
    return _input('number', opts);
  };
  input.password = function (opts) {
    return _input('password', opts);
  };
  input.range = function (opts) {
    return _input('range', opts);
  };
  input.reset = function (opts) {
    return _input('reset', opts);
  };
  input.search = function (opts) {
    return _input('search', opts);
  };
  input.submit = function (opts) {
    return _input('submit', opts);
  };
  input.tel = function (opts) {
    return _input('tel', opts);
  };
  input.text = function (opts) {
    return _input('text', opts);
  };
  input.time = function (opts) {
    return _input('time', opts);
  };
  input.url = function (opts) {
    return _input('url', opts);
  };
  input.week = function (opts) {
    return _input('week', opts);
  };

  var swapChecked = function swapChecked($input) {
    /*
    Swaps $input.prop so that, whenever $input.prop("checked", ...) is called to set whether $input
    is checked, we also update the content of $input.rx("checked") with the same.
    */
    $input._oldProp = $input.prop;
    $input.prop = function () {
      for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
        args[_key] = arguments[_key];
      }

      var res = $input._oldProp.apply($input, _toConsumableArray(Array.from(args || [])));
      if (args.length > 1 && args[0] === "checked") {
        $input.rx("checked").set($input.prop("checked"));
      }
      return res;
    };
    return $input;
  };

  input.checkbox = function (opts) {
    return (
      /*
      A checkbox with a default property `data-unchecked-value` of "false".  This is so that if you
      use $.serializeJSON() to read the value of this checkbox in a form, the value will be false
      if it is unchecked.
      */
      swapChecked(input(_underscore2.default.extend({ type: "checkbox" }, opts)))
    );
  };

  input.radio = radio = function radio(opts) {
    return swapChecked(input(_underscore2.default.extend({ type: "radio" }, opts)));
  };

  svg_tags = _underscore2.default.object(svg_tags.map(function (svg_tag) {
    return [svg_tag, svg_mktag(svg_tag)];
  }));

  var rawHtml = function rawHtml(html) {
    return new RawHtml(html);
  };
  var specialChar = function specialChar(code, tag) {
    if (tag == null) {
      tag = 'span';
    }return rawHtml('<' + tag + '>&' + code + ';</' + tag + '>');
  };
  var unicodeChar = function unicodeChar(code, tag) {
    if (tag == null) {
      tag = 'span';
    }return rawHtml('<' + tag + '>\\u' + code + ';</' + tag + '>');
  };
  //
  // rxt utilities
  //

  // a little underscore-string inlining
  var trim = _jquery2.default.trim;

  var dasherize = function dasherize(str) {
    return trim(str).replace(/([A-Z])/g, '-$1').replace(/[-_\s]+/g, '-').toLowerCase();
  };

  specialAttrs.style = function (elt, value) {
    var isCell = value instanceof rx.ObsCell;
    return rx.autoSub(rx.cast(value).onSet, function () {
      var _Array$from17 = Array.from(arguments.length <= 0 ? undefined : arguments[0]),
          _Array$from18 = _slicedToArray(_Array$from17, 2),
          o = _Array$from18[0],
          n = _Array$from18[1];

      if (n == null || _underscore2.default.isString(n)) {
        setProp(elt, 'style', n);
      } else {
        elt.removeAttr('style').css(n);
      }
      if (isCell && events.enabled) {
        return events.onElementAttrsChanged.pub({ $element: elt, attr: "style" });
      }
    });
  };

  var smushClasses = function smushClasses(xs) {
    return (0, _underscore2.default)(xs).chain().flatten().compact().value().join(' ').replace(/\s+/, ' ').trim();
  };

  specialAttrs.class = function (elt, value) {
    return setDynProp(elt, 'class', value, function (val) {
      if (_underscore2.default.isString(val)) {
        return val;
      } else {
        return smushClasses(val);
      }
    });
  };

  var rxt = exports.rxt = {
    events: events, RawHtml: RawHtml, specialAttrs: specialAttrs, mktag: mktag, svg_mktag: svg_mktag, tags: tags, svg_tags: svg_tags, rawHtml: rawHtml, specialChar: specialChar, unicodeChar: unicodeChar,
    trim: trim, dasherize: dasherize, smushClasses: smushClasses
  };
});

//# sourceMappingURL=main.js.map