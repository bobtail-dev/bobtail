rxFactory = (rx, _, $) ->
  $.fn.rx = (prop) ->
    map = @data('rx-map')
    if not map? then @data('rx-map', map = Object.create null)
    if prop of map then return map[prop]
    map[prop] =
      switch prop
        when 'focused'
          focused = rx.cell(@is(':focus'))
          @focus -> focused.set(true)
          @blur -> focused.set(false)
          focused
        when 'val'
          val = rx.cell(@val())
          @change => val.set(@val())
          @on 'input', => val.set(@val())
          val
        when 'checked'
          checked = rx.cell(@is(':checked'))
          @change => checked.set(@is(':checked'))
          checked
        else
          throw new Error('Unknown reactive property type')

  #
  # reactive template DSL
  #

  rxt = {}
  
  prepContents = (contents) ->
    if contents instanceof rx.ObsCell or contents instanceof rx.ObsArray or _.isArray contents
      contents = rx.flatten contents
    return contents
  
  rxt.events = {}
  rxt.events.enabled = false
  rxt.events.onElementChildrenChanged = new rx.Ev()
  rxt.events.onElementAttrsChanged = new rx.Ev()

  RawHtml = class rxt.RawHtml
    constructor: (@html) ->

  # jQuery events are special attrs, along with `init`

  events = ["blur", "change", "click", "dblclick", "error", "focus", "focusin",
    "focusout", "hover", "keydown", "keypress", "keyup", "load", "mousedown",
    "mouseenter", "mouseleave", "mousemove", "mouseout", "mouseover", "mouseup",
    "ready", "resize", "scroll", "select", "submit", "toggle", "unload"]

  svg_events = ["click"]

  specialAttrs = rxt.specialAttrs = {
    init: (elt, fn) -> fn.call(elt)
  }

  for ev in events
    do (ev) ->
      specialAttrs[ev] = (elt, fn) ->
        if elt instanceof SVGElement and ev in svg_events
          elt.addEventListener ev, fn
        else
          elt[ev]((e) -> fn.call(elt, e))

  # attr vs prop:
  # http://blog.jquery.com/2011/05/10/jquery-1-6-1-rc-1-released/
  # http://api.jquery.com/prop/

  props = ['async', 'autofocus', 'checked', 'location', 'multiple', 'readOnly',
    'selected', 'selectedIndex', 'tagName', 'nodeName', 'nodeType',
    'ownerDocument', 'defaultChecked', 'defaultSelected']
  propSet = _.object([prop, null] for prop in props)

  setProp = (elt, prop, val) ->
    if elt instanceof SVGElement
      elt.setAttribute prop, val
    else if prop == 'value'
      elt.val(val)
    else if prop of propSet
      elt.prop(prop, val)
    else
      elt.attr(prop, val)

  setDynProp = (elt, prop, val, xform = _.identity) ->
    if val instanceof rx.ObsCell
      rx.autoSub val.onSet, ([o,n]) ->
        setProp(elt, prop, xform(n))
        if rxt.events.enabled
          rxt.events.onElementAttrsChanged.pub {$element: elt, attr: prop}
    else
      setProp(elt, prop, xform(val))

  # arguments to a tag may be:
  #   ()
  #   (attrs: Object)
  #   (contents: Contents)
  #   (attrs: Object, contents: Contents)
  # where Contents is:
  #   string | number | Element | RawHtml | $ | Array | ObsCell | ObsArray
  normalizeTagArgs = (arg1, arg2) ->
    if not arg1? and not arg2?
      [{}, null]
    else if arg1 instanceof Object and arg2?
      [arg1, arg2]
    else if not arg2? and
        _.isString(arg1) or
        _.isNumber(arg1) or
        arg1 instanceof Element or
        arg1 instanceof SVGElement or
        arg1 instanceof RawHtml or
        arg1 instanceof $ or
        _.isArray(arg1) or
        arg1 instanceof rx.ObsCell or
        arg1 instanceof rx.ObsArray or
        arg1 instanceof rx.ObsSet
      [{}, arg1]
    else
      [arg1, null]

  toNodes = (contents) ->
    for child in contents
      if child?
        if _.isString(child) or _.isNumber(child)
          document.createTextNode(child)
        else if child instanceof Element or child instanceof SVGElement
          child
        else if child instanceof RawHtml
          parsed = $(child.html)
          throw new Error('RawHtml must wrap a single element') if parsed.length != 1
          parsed[0]
        else if child instanceof $
          throw new Error('jQuery object must wrap a single element') if child.length != 1
          child[0]
        else
          throw new Error("Unknown element type in array: #{child.constructor.name} (must be string, number, Element, RawHtml, or jQuery objects)")

  updateContents = (elt, contents) ->
    elt.html('') if elt.html
    if not contents?
      return
    else if _.isArray(contents)
      nodes = toNodes(contents)
      elt.append(nodes)
      if false # this is super slow
        hasWidth = (node) ->
          try $(node).width()? != 0
          catch e then false
        covers = for node in nodes ? [] when hasWidth(node)
          {left, top} = $(node).offset()
          $('<div/>').appendTo($('body').first())
            .addClass('updated-element').offset({top,left})
            .width($(node).width()).height($(node).height())
        setTimeout (-> $(cover).remove() for cover in covers), 2000
      return nodes
    else if _.isString(contents) or _.isNumber(contents) or contents instanceof Element or
        contents instanceof SVGElement or contents instanceof RawHtml or contents instanceof $
      return updateContents(elt, [contents])
    else
      throw new Error("Unknown type for element contents: #{contents.constructor.name} (accepted types: string, number, Element, RawHtml, jQuery object of single element, or array of the aforementioned)")

  rxt.mktag = mktag = (tag) ->
    (arg1, arg2) ->
      [attrs, contents] = normalizeTagArgs(arg1, arg2)
      contents = prepContents contents

      elt = $("<#{tag}/>")
      for name, value of _.omit(attrs, _.keys(specialAttrs))
        setDynProp(elt, name, value)
      if contents?
        if contents instanceof rx.ObsArray
          rx.autoSub contents.indexed().onChangeCells, ([index, removed, added]) ->
            elt.contents().slice(index, index + removed.length).remove()
            toAdd = toNodes(added.map ([cell, icell]) -> rx.snap -> cell.get())
            if index == elt.contents().length
              elt.append(toAdd)
            else
              elt.contents().eq(index).before(toAdd)
            if rxt.events.enabled and (removed.length or toAdd.length)
              rxt.events.onElementChildrenChanged.pub {
                $element: elt,
                type: "childrenUpdated"
                added: toAdd
                removed: toNodes(removed.map (cell) -> rx.snap -> cell.get())
              }
            for [cell, icell] in added
              do (cell, icell) ->
                rx.autoSub cell.onSet, rx.skipFirst ([old, val]) ->
                  ival = rx.snap -> icell.get()
                  toAdd = toNodes([val])
                  elt.contents().eq(ival).replaceWith(toAdd)
                  if rxt.events.enabled
                    rxt.events.onElementChildrenChanged.pub {
                      $element: elt, type: "childrenUpdated", updated: toAdd
                    }
        else
          updateContents(elt, contents)
      for key of attrs when key of specialAttrs
        specialAttrs[key](elt, attrs[key], attrs, contents)
      elt

  # From <https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/HTML5/HTML5_element_list>
  #
  # Extract with:
  #
  #     "['"+document.body.innerText.match(/<.*?>/g).map(function(x){return x.substring(1, x.length-1);}).join("', '")+"']";

  tags = ['html', 'head', 'title', 'base', 'link', 'meta', 'style', 'script',
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
    'menuitem', 'menu']

  # From <https://developer.mozilla.org/en-US/docs/Web/SVG/Element>
  svg_tags = ['a', 'altglyph', 'altglyphdef', 'altglyphitem', 'animate',
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
    'textpath', 'title', 'tref', 'tspan', 'use', 'view', 'vkern']

  updateSVGContents = (elt, contents) ->
    (elt.removeChild elt.firstChild) while elt.firstChild
    if _.isArray(contents)
      toAdd = toNodes(contents)
      (elt.appendChild node) for node in toAdd
    else if _.isString(contents) or contents instanceof SVGElement
      updateSVGContents(elt, [contents])
    else
      console.error 'updateSVGContents', elt, contents
      throw "Must wrap contents #{contents} as array or string"

  rxt.svg_mktag = mktag = (tag) ->
    (arg1, arg2) ->
      [attrs, contents] = normalizeTagArgs(arg1, arg2)

      elt = document.createElementNS('http://www.w3.org/2000/svg', tag)
      for name, value of _.omit(attrs, _.keys(specialAttrs))
        setDynProp(elt, name, value)

      if contents?
        if contents instanceof rx.ObsArray
          contents.onChange.sub ([index, removed, added]) ->
            (elt.removeChild elt.childNodes[index]) for i in [0...removed.length]
            toAdd = toNodes(added)
            if index == elt.childNodes.length
              (elt.appendChild node) for node in toAdd
            else
              (elt.childNodes[index].insertBefore node) for node in toAdd
        else if contents instanceof rx.ObsCell
          contents.onSet.sub(([old, val]) -> updateSVGContents(elt, val))
        else
          updateSVGContents(elt, contents)

      for key of attrs when key of specialAttrs
        specialAttrs[key](elt, attrs[key], attrs, contents)
      elt

  rxt.tags = _.object([tag, rxt.mktag(tag)] for tag in tags)
  {input} = rxt.tags

  _input = (type, opts) -> input _.extend {type}, opts
  input.color = (opts) -> _input 'color', opts
  input.date = (opts) -> _input 'date', opts
  input.datetime = (opts) -> _input 'datetime', opts
  input.datetimeLocal = (opts) -> _input 'datetime-local', opts
  input.email = (opts) -> _input 'email', opts
  input.file = (opts) -> _input 'file', opts
  input.hidden = (opts) -> _input 'hidden', opts
  input.image = (opts) -> _input 'image', opts
  input.month = (opts) -> _input 'month', opts
  input.number = (opts) -> _input 'number', opts
  input.password = (opts) -> _input 'password', opts
  input.range = (opts) -> _input 'range', opts
  input.reset = (opts) -> _input 'reset', opts
  input.search = (opts) -> _input 'search', opts
  input.submit = (opts) -> _input 'submit', opts
  input.tel = (opts) -> _input 'tel', opts
  input.text = (opts) -> _input 'text', opts
  input.time = (opts) -> _input 'time', opts
  input.url = (opts) -> _input 'url', opts
  input.week = (opts) -> _input 'week', opts

  swapChecked = ($input) ->
    ###
    Swaps $input.prop so that, whenever $input.prop("checked", ...) is called to set whether $input
    is checked, we also update the content of $input.rx("checked") with the same.
    ###
    $input._oldProp = $input.prop
    $input.prop = (args...) ->
      res = $input._oldProp(args...)
      if args.length > 1 and args[0] == "checked"
        $input.rx("checked").set $input.prop("checked")
      return res
    return $input

  input.checkbox = (opts) ->
    ###
    A checkbox with a default property `data-unchecked-value` of "false".  This is so that if you
    use $.serializeJSON() to read the value of this checkbox in a form, the value will be false
    if it is unchecked.
    ###
    swapChecked input _.extend({type: "checkbox"}, opts)

  input.radio = radio = (opts) -> swapChecked input _.extend({type: "radio"}, opts)

  rxt.svg_tags = _.object([tag, rxt.svg_mktag(tag)] for tag in svg_tags)

  rxt.rawHtml = (html) -> new RawHtml(html)
  rxt.specialChar = (code, tag='span') -> rxt.rawHtml "<#{tag}>&#{code};</#{tag}>"
  rxt.unicodeChar = (code, tag='span') -> rxt.rawHtml "<#{tag}>\\u#{code};</#{tag}>"
  rxt.importTags = (x) => _(x ? this).extend(rxt.tags)
  #
  # rxt utilities
  #

  rxt.cast = (value, type = "cell") ->
    console.warn "Warning: rx.rxt.cast is deprecated. Use rx.cast instead."
    return rx.cast value, type

  # a little underscore-string inlining
  rxt.trim = $.trim

  rxt.dasherize = (str)->
    rxt.trim(str).replace(/([A-Z])/g, '-$1').replace(/[-_\s]+/g, '-').toLowerCase()

  rxt.cssify = (map) ->
    console.warn 'cssify is deprecated; set the `style` property directly to a JSON object.'
    (
      for k,v of map when v?
        "#{rxt.dasherize(k)}: #{if _.isNumber(v) then v+'px' else v};"
    ).join(' ')

  specialAttrs.style = (elt, value) ->
    isCell = value instanceof rx.ObsCell
    rx.autoSub rx.cast(value).onSet, ([o,n]) ->
      if not n? or _.isString(n)
        setProp(elt, 'style', n)
      else
        elt.removeAttr('style').css(n)
      if isCell and rxt.events.enabled
        rxt.events.onElementAttrsChanged.pub {$element: elt, attr: "style"}

  rxt.smushClasses = (xs) ->
    _(xs).chain().flatten().compact().value().join(' ').replace(/\s+/, ' ').trim()

  specialAttrs.class = (elt, value) ->
    setDynProp elt, 'class', value, (val) ->
      if _.isString(val) then val else rxt.smushClasses(val)

  rx.rxt = rxt
  return rx
# end rxFactory definition

do(root = this, factory = rxFactory) ->
  deps = ['bobtail-rx', 'jquery']

  if define?.amd?
    define deps, factory
  else if module?.exports?
    rx = require 'bobtail-rx'
    $ = require 'jquery'
    _ = require 'underscore'
    require 'es5-shim'
    require 'es6-shim'
    module.exports = factory rx, _, $
  else if root._? and root.$? and root.rx
    factory root.rx, root._, root.$
  else
    missing = [
      if not root.rx? then 'bobtail-rx'
      if not root._? then '_'
      if not root.$? then '$'
    ].filter (x) -> x
    throw "Dependencies are not met for bobtail: #{missing.join ','} not found"
