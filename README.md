reactive-coffee
===============

Declaratively specify your DOM templates in a simple CoffeeScript embedded DSL.

Examples
--------

A regular static DOM:

```
$('body').append(
  div { class: 'main-content' }, [
    h1 {}, [ 'Hello world!' ]
    ul { class: 'nav' }, [
      li {}, [ 'Home' ]
      li {}, [ 'About' ]
      li {}, [ 'Contact' ]
    ]
    input { type: 'text', placeholder: 'Your name here' }
  ]
)
```

A simple reactive example:

```
# Our model
a = rx.cell(0)
b = rx.cell(0)

# `bind` subscribes to the contained cell values, ensuring that (e.g.) `abtn` *always* shows the current value of `a`
abtn = button {}, bind -> [ "#{a.get()}" ]
bbtn = button {}, bind -> [ "#{b.get()}" ]
# Tags are just jQuery objects
abtn.click -> a.set(a.get() + 1)
bbtn.click -> b.set(b.get() + 1)

$('body').append(
  div { class: 'formula' }, [
    abtn
    bbtn
    # We can bind to any number of things
    span { class: 'result' }, bind -> [ "#{a.get() + b.get()}" ]
  ]
)
```

Recursively render a tree, something that's a bit more cumbersome to incrementally maintain otherwise:

```
class TreeNode
  constructor: (value, children) ->
    @value = rx.cell(value)
    # Arrays only insert/remove the minimum set into/from the DOM (via the `map` method)
    @children = rx.array(children)

root = new TreeNode 'root', [
  new TreeNode 'alpha', []
  new TreeNode 'beta', [
    new TreeNode 'gamma', []
    new TreeNode 'delta', []
  ]
]

# Nested `bind`/`map` calls are insulated from parents, re-rendering only what's necessary.
recurse = (node) ->
  li {}, [
    span {}, bind -> [ node.value.get() ]
    ul {}, node.children.map -> recurse
  ]

$('body').append( ul {}, [ recurse(root) ] )
```

Development Setup
-----------------

To fetch node dependencies:

    npm install # pull dependencies into ./node_modules
    npm install -g phantomjs # temp workaround for karma phantomjs launcher

To build and test:

    grunt

To test:

    grunt test

Tests may spew this error after running:

    ERROR [launcher]: Cannot start PhantomJS

You can ignore this; it was fixed recently in
<https://github.com/karma-runner/karma/issues/444>.

See Also
--------

- Any of the multitude of declarative UI toolkits based on reactive programming
- Specifically in JS land: [Knockout] in terms of mechanics, [Ember]/[Angular] in terms of templating spirit
- [Visage], formerly known as JavaFX, for DSL syntax

[Knockout]: //knockoutjs.com
[Ember]: //emberjs.com
[Angular]: //angularjs.org
[Visage]: //code.google.com/p/visage
