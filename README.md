reactive.coffee
===============

A lightweight CoffeeScript library for reactive programming and for
declaratively specifying reactive DOM templates in a simple embedded DSL.

This library has been tested and used on Chrome, Firefox, Safari, and IE10.

Quickstart Examples
-------------------

Here's a quick taste of what using Reactive is like.

A regular static DOM:

```coffeescript
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

```coffeescript
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

Recursively render a tree, something that's a bit more cumbersome to
incrementally maintain otherwise:

```coffeescript
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

# Nested `bind`/`map` calls are insulated from parents, re-rendering only
# what's necessary.
recurse = (node) ->
  li {}, [
    span {}, bind -> [ node.value.get() ]
    ul {}, node.children.map -> recurse
  ]

$('body').append( ul {}, [ recurse(root) ] )
```

You can also have things elements depend certain attributes of each other.
Here is a text box that searches/filters the given list.

```coffeescript
countries = [...]
$searchBox = input {
  type: 'text'
  placeholder: 'Type a country name'
}
ul {}, bind ->
  for country in countries
    if _(country).startsWith($searchBox.rx('text'))
      li {}, [country]
```

Currently there is a complete [TodoMVC] example in the `examples/` directory
(see the [source]).  More examples will be added!

[TodoMVC]: http://todomvc.com/
[source]: https://github.com/yang/reactive-coffee/blob/master/examples/todomvc/index.jade

Motivation and Design Rationale
-------------------------------

With so many client-side model-view web frameworks out there, why create yet
another one?  What's so special about this one?

The goals of this particular framework are to strive for elegance and
simplicity of mechanism in a package that minimizes "magic," while at the same
time achieving the expressiveness of frameworks that allow for declarative
specification of data-bound template views which react immediately to changes
in the model.  Another core goal is to have foundations in composable core
primitives that scale well in both performance and code architecture to complex
applications involving both large numbers of bindings and deep/complex model
structures.

Reactive actually consists of two layers.  At its core, it provides reactive
programming primitives that allows users to declaratively specify arbitrary
dataflow DAGs, where data structures are automatically updated in response to
updates in their dependencies.  This is in lieu of the more complex event
systems powering systems like [Backbone].  The idea is that all application
dependencies, including high-level business logic and domain-specific concepts,
are conveniently represented by (potentially complex) data types built out of
observable nodes.

[Backbone]: http://backbonejs.org/

The second layer in Reactive is that of the "template language," the DSL for
constructing UIs out of not only DOM elements but arbitrary user-defined
components as well.

A major benefit of embedding into a host language that is a full-fledged
programming language, rather than creating a limited template language, is that
the system now inherits the abstractions and expressive power of the host
language for free.  For instance, defining reusable component abstractions is
as simple as.  The ability to define reusable components, and the manner in
which they are assembled together, is at the core of what makes for scalable
architecture, and this is an area where Reactive is very simple.  Plus, we
inherit all the expressivity of the host language, control flow (loops and
conditionals), variables, expressions, and so forth.

Furthermore, by avoiding the creation of a new language (even simple syntactic
transforms), you retain all the benefits of the tooling around an established
host language, such as source maps, syntax highlighting, linting, comment doc
processing, compiler implementations, etc.

The syntax leverages some features of CoffeeScript to achieve the expressive
power of a declarative HTML-ish template language:

- [general malleability][DSLs] for DSLs, esp. for declaring structures
- concise anonymous function definitions for delimiting bindings to re-compute
- string interpolation
- reuse any code you've already written

[DSLs]: https://github.com/jashkenas/coffee-script/wiki/%5Bextensibility%5D-writing-DSLs

At the same time, because we are simply writing CoffeeScript, we have all the
flexibility and code which that brings to the table, useful for shaping data
for the views as well as for specifying component behavior.  Reactive is
designed for rich application development.  This is a developer-centric
framework that does not pretend to be something that is used by designers or
tools.  Rather than focusing on the division between markup and logic, Reactive
focuses on separating models from views and on the component abstraction.
Components must encapsulate not just markup, but also behavior.  The two should
be coupled, not separated.

This library also takes the stance that logic-less is a counter-productive
endeavor---the gains are primarily superficial, readability can be *adversely*
affected, and it does not separate concerns.  Others have [written] [more] on
this.

[written]: http://boronine.com/2012/09/07/Cult-Of-Logic-less-Templates/
[more]: http://www.ebaytechblog.com/2012/10/01/the-case-against-logic-less-templates/

Finally, Reactive also aims to be a compact framework.  The documentation
you're now reading is significantly longer than the code.

Tutorial
--------

### Getting Started

Reactive depends on jQuery and Underscore.

```html
<script src='//ajax.googleapis.com/ajax/libs/jquery/1.10.1/jquery.min.js'></script>
<script src='//cdnjs.cloudflare.com/ajax/libs/underscore.js/1.4.4/underscore-min.js'></script>
<script src='reactive-coffee.min.js'></script>
```

To start using the tags directly without having to prefix them with the `rxt`
namespace, use:

```coffeescript
rxt.importTags()
```

If you're using `bower`, these should be transitively pulled in, but `bower`
has issues solving dependency version constraints.

### Cells

The core building block is an _observable cell_, `ObsCell`.

```coffeescript
x = rx.cell()
```

A cell is just a container for a value (initialized to `undefined` above, but
you could also have passed in an initial value).  You can `get`/`set` this
value:

```coffeescript
x.set(3)
x.get() # 3
```

### Events

The special thing about observables is that you can _subscribe_ to events on
them, where events are fired when the value of the cell changes in some way.
For simple cells like the above, there's just a single _on-set_ event type:

```coffeescript
subscription = x.onSet.sub ([oldVal, newVal]) ->
  console.log "x was set from #{oldVal} to #{newVal}"
```

The listener is just a simple callback.  All event types take callbacks of a
single argument—the type of that argument is event-specific, and in the case of
`onSet` it's a pair of `[old value, new value]`.  The `sub` method returns a
unique identifier for this subscription, which can later be used to unsubscribe
a listener:

```coffeescript
x.onSet.unsub(subscription)
```

You can now start reacting to these events.  For instance:

```coffeescript
firstName = rx.cell('John')
# This ensures .name will always reflect the firstName
firstName.sub ([oldVal, newVal]) ->
  $('.name').text(newVal)
firstName.set('Jane')
```

### Dependent Cells

The above is a simple way of updating but it's a bit verbose.  In most UI
frameworks, you have fewer models but many more visual representations of the
model.

To extend the above example, let's say you now had a displayed name that
depended on two cells (comprising your "model").  You could just create
explicit subscriptions and listeners:

```coffeescript
firstName = rx.cell('John')
lastName = rx.cell('Smith')

updateName = ->
  $('.name').text("#{firstName.get()} #{lastName.get()}")
firstName.sub -> updateName
lastName.sub -> updateName

firstName.set('Jane')
lastName.set('Doe')
```

However, the primary way in which these cells are to be composed is via `bind`,
which lets you simply write an expression or function in terms of the dependent
nodes:

```coffeescript
fullName = bind -> "#{firstName.get()} #{lastName.get()}"
```

Now, `fullName` is always bound to the `firstName + lastName`.  Key here is
that no explicit subscription management is necessary.  This scales well to
more complex dependencies, and is more readable/declarative:

```coffeescript
displayName = bind ->
  if showRealName.get()
    "Full name: #{fullName.get()}"
  else
    "Fake naem: #{fakeName.get()}"
```

The bindings are managed such that only the dependent cells that could possibly
affect the result are effective dependencies.  In this example, at any moment,
`fullName` depends either only on `showRealName` and `fulName` *or* only on
`showRealName` and `fakeName`.  If `showRealName` is false, changes to
`firstName` and `lastName` will not trigger a re-render of the `.name`.

`firstName` and `lastName` are _source cells_ that support setting of values.
`fullName` is itself also a cell, but a "read-only" _dependent cell_ that we
can bind to some expression of source cells.  These do not have a `set` method.

Dependent cells can in turn be bound to as well:

```coffeescript
greeting = bind -> "Welcome back #{fullName.get()}!"
```

These bindings can form an arbitrary DAG.

Reactive programming is the same concept behind how spreadsheet calculations
work, and is similar to the data-binding feature present in many of the other
frameworks---which is an effective paradigm for frontend UI development---but
instead of being exclusively applied to view components, typically confined to
a template language, this is generalized to be a generic way of expressing
arbitrary time-varying data structures.

### Arrays and Maps

Cells are the most general type of observable container.  However, there are
also observable containers with special support for arrays and objects.  This
special support is to support more efficient and fine-grained event types
reflecting changes to particular sub-parts rather than an all-encompassing
`onSet` event.  For instance, arrays commonly have elements inserted or removed
from them, in which case we'd like to avoid re-rendering entire dependent
sections of the DOM or otherwise needing to figure out what parts have changed.

Arrays support a `onChange` is a particularly special type of event.  It fires
with a triple `[index, removed, added]`, where `index` is the offset into the
array where the change is happening, `removed` is the sub-array of elements
removed, and `added` is the sub-array of elements inserted.  Example:

```coffeescript
xs = rx.array([1,2,3])
xs.onChange.sub ([index, removed, added]) ->
  console.log "replaced #{removed.length} element(s) at offset #{index} with #{removed.length} new element(s)"
xs.push(4)
# replaced 0 element(s) at offset 3 with 1 new element(s)
```

### Static Templates

Now for a brief jump to something entirely different....

The "template" system is implemented as an embedded domain-specific language
(DSL) in CoffeeScript, which happens to have a syntax that [lends itself
well][DSLs] to expressing the template structure.

[DSLs]: https://github.com/jashkenas/coffee-script/wiki/%5Bextensibility%5D-writing-DSLs

Here's a simple template:

```coffeescript
div {class: 'sidebar'}, [
  h2 {}, ['Send a message']
  form {action: '/msg', method: 'POST'}, [
    input {type: 'text', name: 'comment', placeholder: 'Your message'}
    select {name: 'recipient'}, [
      option {value: '0'}, ['John']
      option {value: '1'}, ['Jane']
    ]
    button {class: 'submit-btn'}, ['Send']
  ]
]
```

It translates to the following HTML:

```coffeescript
<div class="sidebar">
  <h2>Send a message</h2>
  <form action='/msg' method='POST'>
    <input type='text' name='comment' placeholder='Your message'/>
    <select name='recipient'>
      <option value='0'>John</option>
      <option value='1'>Jane</option>
    </select>
    <button class='submit-btn'>Send</button>
  </form>
</div>
```

Since this is CoffeeScript, you can embed arbitrary logic:

```coffeescript
# Loops:

ul {class: 'friends'},
  for name in names
    li {class: 'friend'}, [name]

# Or equivalently:

ul {class: 'friends'}, names.map(name) ->
  li {class: 'friend'}, [name]

# Conditionals:

div {class: 'profile'}, [
  img {src: "#{user.picUrl}"}
  if signedIn
    button {}, ["Add #{user.name}" as a friend."]
  else
    p {}, ["Sign up to connect with #{user.name}!"]
]
```

Tags are really just functions that return DOM elements (wrapped in jQuery
objects), so you are free to attach behaviors to them:

```coffeescript
$button = button {class: 'submit-btn'}, ['Click Me!']
$button.click -> $(this).text('I been clicked.')
```

However, since often times you may be working with deeply nested templates
structures where it's clumsy to tack on behaviors afterward, you can for
convenience supply a function in an attribute named `init`, which is
immediately invoked with the current element bound to `this`:

```coffeescript
table {}, properties.map (prop) ->
  tr {}, [
    td {}, [prop.name]
    td {}, [
      input {
        type: 'text'
        value: prop.value
        placeholder: 'Enter property value'
        init: -> @blur => setProperty(prop, @val())
      }
    ]
  ]
```

Since CoffeeScript assignments are expressions, we also have a convenient way
of naming elements:

```coffeescript
table {}, properties.map (prop) ->
  $row = tr {}, [
    td {}, [prop.name]
    td {}, [
      input {
        type: 'text'
        value: prop.value
        placeholder: 'Enter property value'
        init: -> @blur =>
          $row.css('opacity', .5)
          setProperty(prop, @val())
      }
    ]
  ]
```

### Reactive Templates

Reactive templates tie together the UI-building style from the previous section
with the reactive programming primitives from earlier.

You could just write explicit imperative code to transform the DOM in a way
that consistently reflects the bindings you're interested in.  For instance:

```coffeescript
$('body').append(input {
  class: 'name passive'
  type: 'text'
  placeholder: 'Name'
  value: ''
})
displayName.onSet.sub ([oldVal, newVal]) ->
  $('.name').val(newVal)
isActive.onSet.sub ([oldVal, newVal]) ->
  if newVal
    $('.name').removeClass('passive').addClass('active')
  else
    $('.name').removeClass('active').addClass('passive')
```

However, more complex transformations can become more involved.

```coffeescript
names = rx.array(['1','2','3','4','5'])
$('body').append($nameList = div {class: 'name-list'})
spans = names.map (name) -> span {}, [name]
spans.onChange.sub ([index, added, removed]) ->
  # Homework: fill in logic heer for efficiently inserting/removing DOM
  # nodes!
```

You also shouldn't have to repeatedly code this logic any time you want to make
bindings, and it would be much more clear to specify the template
declaratively:

```coffeescript
$('body').append(
  input {
    class: bind -> "name #{if isActive.get() then 'active' else 'passive'}"
    type: 'text'
    placeholder: 'Name'
    value: bind -> displayName.get()
  }
)

$('body').append(
  div {class: 'name-list'}, names.map (name) ->
    span {}, [name]
)
```

You're declaring what the UI should *always look like over time*, and the
system frees you from the responsibility of maintaining this.

Here's another quick example, this one of a todo list.  Notice how here we are
using a raw array in a cell, rather than an `rx.array`.  This is fine but not
as efficient in the face of large arrays.

```coffeescript
tasks = rx.cell(['Get milk', 'Take out trash', 'Clean up room'])
$('body').append(
  ul {class: 'tasks'}, bind ->
    for task in tasks.get()
      li {class: 'task'}, ["User: #{task}"]
)
```

Any attribute can be a cell:

```coffeescript
input { value: bind -> displayName.get() }
```

the contents can be a cell that returns an array (of strings or elements):

```coffeescript
span {}, bind -> [displayName.get()]
div {}, bind -> names.all()
```

or an observable array:

```coffeescript
div {}, names
# results in: <div>01234</div>

div {}, names.map (name) ->
  span {}, [name]
# results in: <div><span>0</span><span>1</span>...</div>
```

You have very fine-grained control over the re-rendering process.  For
instance, say we had a model like the following:

```coffeescript
class User
  constructor: (id, name) ->
    @id = rx.cell(id)
    @name = rx.cell(name)

class App
  constructor: (users) ->
    @users = rx.array(users)

app = new App([
  new User('John', 0)
  new User('Jane', 1)
])
```

If we wanted to just re-render individual elements, we could do that with:

```coffeescript
select {}, app.users.map (user) ->
  option {value: bind -> "#{user.id.get()}"}, bind -> "#{user.name.get()}"
```

On the other hand, if we wanted to re-render the entire section whenever
anything changed, we could do so with:

```coffeescript
select {}, bind -> app.users.all().map (user) ->
  option {value: "#{user.id.get()}"}, "#{user.name.get()}"
```

Nested `bind`/`map` calls are insulated from outer calls, re-rendering only
what's necessary.

### Components

Making reusable components is as simple as defining a function:

```coffeescript
tabs = (opts) ->
  opts = _(opts).defaults
    tabs: []
    initialTabIndex: 0
    activeClass: 'active-tab'

  activeTabIndex = rx.cell(opts.initialTabIndex)

  div {class: 'tabs'}, [
    ul {class: 'nav-tabs'}, opts.tabs.map ([tabName, tabContents], i) ->
      li {
        class: bind ->
          [
            "nav-tab"
            "#{if activeTabIndex.get() == i then opts.activeClass else ''}"
          ].join(' ')
        init: -> @click => activeTabIndex.set(i)
      }, [tabName]
    div {class: 'tab-content'}, bind ->
      [tabName, tabContents] = opts.tabs.at(activeTabIndex.get())
      tabContents
  ]
```

Now we can use this with:

```coffeescript
tabs {
  activeClass: 'my-active-tab'
  tabs: rx.array([
    ['Properties', modifyTab()]
    ['Create', createTab()]
    ['Styles', stylesTab()]
  ])
}
```

When defining abstractions, it's almost always better to err on the side of
making everything dynamic, since you can always opt-out of dynamism by stopping
propagation, whereas you cannot later reintroduce dynamism into places with no
dynamic bindings.

API Documentation
-----------------

### `rx` Namespace

This contains the core reactive programming primitives.  These are the core
data structures:

- `ObsCell`: observable cell base class
    - `SrcCell`: a source cell, one that can be directly mutated
    - `DepCell`: a dependent cell, one whose value is some function of another
      observable cell
- `ObsArray`: observable array base class
    - `SrcArray`: a source array, one that can be directly mutated
    - `DepArray`: a dependent array, one whose value is some transformation of
      another observable array
- `ObsMap`: observable object (map) base class
    - `SrcMap`: a source object, one that can be directly mutated
    - `DepMap`: a dependent object, one whose value is some transformation of
      another observable object

**Free functions**

- `cell(value)`: return a `SrcCell` initialized to the given value (optional;
  defaults to `undefined`)
- `array(value)`: return a `SrcArray` initialized to the given array (optional;
  defaults to `[]`)
- `bind(fn)`: given a 0-ary function, return a `DepCell` whose value is the
  bound to the result of evaluating that function.  The function is immediately
  evaluated once, and each time it's evaluated, for any accesses of
  observables, the `DepCell` subscribes to the corresponding events, which may
  subsequently trigger future re-evaluations.
- `lagBind(init, fn)`: same as `bind` but waits a 500ms delay after getting an
  update before the `DepCell` updates itself (yes, this needs to be a
  configurable parameter)

**`ObsCell`**

- `get()`: return current value of the cell

**`SrcCell`**

- `set(x)`: set value of cell to `x`

**`ObsArray`**

- `at(i)`: return element at `i`
- `all()`: return raw array copy of all elements
- `length()`: return size of the array
- `map(fn)`: return `DepArray` of given function mapped over this array

**`SrcArray`**

- `splice(index, count, additions...)`: replace `count` elements starting at
  `index` with `additions`
- `insert(x, i)`: insert value `x` at index `i`
- `remove(x)`: find and remove first occurrence of `x`
- `removeAt(i)`: remove element at index `i`
- `push(x)`: append `x` to the end of the array
- `put(i, x)`: replace element `i` with value `x`
- `replace(xs)`: replace entire array with raw array `xs`

**`ObsMap`**

- `get(k)`: return value associated with key `k`
- `all()`: return raw object copy

**`SrcMap`**

- `put(k, v)`: associate value `v` with key `k` and return any prior value associated with `k`
- `remove(k)`: remove the entry associated at key `k`

### `rxt` Namespace

This contains the template DSL constructs.  Main thing here is the _tag
function_, which is what constructs a DOM element.

**Free functions**

- `mktag(tag)`: returns a tag function of the given tag name.  The other tags
  are simply aliases to this, e.g.: `div = mktag('div')`.
- `importTags()`: populate the global namespace with the tag symbols, so you
  don't need have `rxt` all over your templates.  Useful for quickly throwing
  something together.
- `rawHtml(html)`: wrapper for strings that tags won't escape when rendering;
  example: `div {}, [rawHtml('<span>hello</span>')]`
- Tags: `p`, `br`, `ul`, `li`, `span`, `anchor`, `div`, `input`, `select`,
  `option`, `label`, `button`, `fieldset`, `legend`, `section`, `header`,
  `footer`, `strong`, `h1`, `h2`, `h3`, `h4`, `h5`, `h6`, `h7`

FAQ
---

**Why yet another client-side framework?**

It's actually generous to call this a framework, (or I guess it can be called a
"micro-framework"), but hopefully most of the questions are addresed in
[Motivation and Design Rationale](#motivation-and-design-rationale) and [See
Also](#see-also).

**Isn't this approach just going back to the PHP days of mixing markup and
logic?**

Reactive is designed for rich application development.  Rather than focusing on
the division between markup and logic, Reactive focuses on separating models
from views and on the component abstraction.  Components must encapsulate not
just markup, but also behavior.  The two should be coupled, not separated.

This library also takes the stance that logic-less is a counter-productive
endeavor---the gains are primarily superficial, readability can be *adversely*
affected, and it does not separate concerns.  Others have [written] [more] on
this.

[written]: http://boronine.com/2012/09/07/Cult-Of-Logic-less-Templates/
[more]: http://www.ebaytechblog.com/2012/10/01/the-case-against-logic-less-templates/

**Why jQuery / what is the relationship between Reactive Coffee and jQuery?**

The library just uses jQuery as a cross-browser interface to the DOM for its
own operations.  All tags are wrapped in jQuery objects.  You don't need to use
jQuery, but jQuery excels as a cross-platform API and is probably the most
popular of managing low-level DOM operations.  Although jQuery is known to not
scale very well, higher-level application structure is where Reactive Coffee
steps in.

**Why the syntax noise in the template language?**

This is actually not set in stone.  The framework could handle a more concise
template syntax.  For instance, it's certainly feasible to support a language
in which one of the above examples could be rewritten as:

```coffeescript
div '.sidebar', [
  h2 'Send a message'
  form {action: '/msg', method: 'POST'}, [
    input {type: 'text', name: 'comment', placeholder: 'Your message'}
    select {name: 'recipient'}, [
      option {value: '0'}, 'John'
      option {value: '1'}, 'Jane'
    ]
  ]
]
```

This would be closer to the concision of languages like Slim and Jade:

```coffeescript
.sidebar
  h2 Send a message
  form(action='/msg' method='POST')
    input(type='text' name='comment' placeholder='Your message')
    select(name='recipient')
      option(value='0') John
      option(value='0') Jane
```

However, the project currently errs on the side of more conservatively adding
syntax to the DSL, and defaulting to strictness.

**How does Reactive stack up against the many other client-side frameworks?**

For now, refer to the [See Also](#see-also) section—hoping to elaborate more on
this soon.

**Can I use this from JavaScript?**

Yes, you can, with caveats.  The main benefit of using CoffeeScript here is
that it has a very friendly syntax for declaring UIs and particularly for the
terse anonymous function syntax to represent the incrementally recomputable
bindings.  However, if you are willing to drop down to the granularity of whole
components and let the system diff changes for you, then it's certainly much
more pragmatic (this would then be similar to the approach used in React).

It's worth showing a quick example of what that would look like:

```javascript
var $sidebar = rx.bind(function() { return
  div({class: 'sidebar'}, [
    h2({}, 'Send a message'),
    form({action: '/msg', method: 'POST'}, [
      input({type: 'text', name: 'comment', placeholder: 'Your message'}),
      select({name: 'recipient'}, users.map(function (user) { return
        option({value: ""+user.id}, [user.name]);
      }))
    ])
  ])
});
```

Development Setup
-----------------

To fetch node dependencies:

    npm install # pull dependencies into ./node_modules
    npm install -g phantomjs # temp workaround for karma phantomjs launcher
    npm install -g grunt-cli # for conveniently running grunt
    npm install -g bower # for conveniently running grunt

To fetch dependencies:

    bower install

To build and test:

    grunt

To test:

    grunt test

Tests may spew this error after running:

    ERROR [launcher]: Cannot start PhantomJS

You can ignore this; it was fixed recently in
<https://github.com/karma-runner/karma/issues/444>.

Community and Support
---------------------

Don't hesitate to reach out with any questions or discussion topics.
Pull requests are extra-welcome.

- [Issue Tracker]
- [Google Groups mailing list]

[Issue Tracker]: https://github.com/yang/reactive-coffee/issues
[Google Groups mailing list]: https://groups.google.com/forum/?fromgroups#!forum/reactive-coffee

Infelicities
------------

There are a number of areas for immediate improvement, including but not
limited to the following:

### Lazy change propagation

This one is rather low-hanging fruit: when a cell's value has been set to the
same value, we should not propagate events downstream to dependent nodes.

### Structural Attributes

Currently, attributes are strings.  For most attributes this is fine, but for
certain attributes such as `style`, we could have a simple convenience
preprocessor that takes in an object map of the style names and renders the
string.  This could be extended to lists for `class` and so on.

### Topologically Ordered Visits

If we consider the DAG of dependencies among observable nodes, when there's an
event being propagated through the system, the notifications currently visit
nodes in depth-first order.  However, the most efficient order in which to
propagate changes is by processing the events of the nodes in topologically
sorted order.  For instance, consider the following DAG:

    A -> B
    A -> C
    B -> D
    C -> D
    D -> E

If `A` is updated, then we'd currently perform a recursive descent starting at
`A` and visit the nodes in this order:

    A, B, D, E, C, D, E

However, if we kept track of the DAG, then we could process the nodes in
topologically sorted order:

    A, B, C, D, E

The main benefit is that this avoids multiple visits to the same node.

The performance effects of this warrants research, but my feeling is that it
scales better and should not be slower for simpler DAGs.

### Lazy Event Notification

More flexible-but-still-efficient array (and other data structure) mutations.
Currently arrays have built-in mechanisms for efficient propagation of events
such as insertion, removal, splicing, etc.  However, for more involved
transformations, or if we want to reuse existing array transformation code, we
can still do better than re-evaluating all dependents downstream by figuring
out what has changed, and then only propagating the diff's instead of (or in
addition to) the full new array.

This can be extended to arbitrary object types/data structures beyond arrays
and should be configurable, with the ability to substitute in various change
detection or diffing algorithms.

### Text Spans

Text chunks are wrapped in span tags.  There's no fundamental reason this is
necessary beyond convenience/speed of implementing the early versions of this
framework.

### Transitions

Ability to apply animations and effects to things like entrances, exits, and
reorderings.  See the [d3 transitions API] for something I'm keen on borrowing
from.

[d3 transitions API]: https://github.com/mbostock/d3/wiki/Transitions

### Tests

And examples.  Need more tests and examples.  'Nuff said.

Ideas
-----

### Automatic Re-Rendering Analysis

The fine-grained control over re-rendering and bindings is powerful, but for
bindings that are non-performance-critical or don't need to scale, it's less
effort to not have to selectively decide where those bindings exist.  Simply
make everything dynamically bound, and then with events being used only to
determine what parts of the model have been dirtied, we can instead let the
framework compute optimal set(s) of the DOM to re-render automatically.

Once everything is a binding, slightly modified/more scalable syntax and idioms
may be warranted, so that instead of:

```coffeescript
ul {class: (bind -> "biglist"), style: (bind -> "display: #{shown}")}, xs.map (x) ->
  li {}, bind -> ["#{x.name}"]
```

we write:

```coffeescript
ul {
  class: -> "biglist"
  style: -> "display: #{shown}"
  contents: xs.map (x) ->
    li { contents: -> ["#{x.name}"] }
}
```

### Object.observe

A platform feature looming on the horizon of ECMAScript is that of
[Object.observe], which allows for reacting to mutation events on objects
without needing explicit syntax for it, e.g.:

```coffeescript
x = 0
foo.x = 3
```

vs.

```coffeescript
x = rx.cell(0)
x.set(3)
```

The main benefit here is that you needn't sprinkle `rx.cell` annotations
everywhere and you can re-use existing code that mutates objects normally
without going through `.set`.  This similarly means that bindings do not need
to explicitly call `.get`, and instead can assume a `.get` on any variable
access.

[Angular] and other frameworks support free-form models, but must do additional
work to re-compute what has actually changed.  The [Polymer] framework
pioneered support for `Object.observe`, but as of this writing it's not a
widely supported feature (only available in Chrome Canary) and the framework
has a more expensive fallback.

### Network Data Bindings

This is flexible, but it would be convenient to have some implementations of
Comet- or WebSocket-based push mechanisms that works well with various
server-side frameworks.

Change Log
----------

v0.0.0 — 2013-06-06

- Initial release.

See Also
--------

There are many other client-side framework for building rich web app UIs.  The
frameworks are inspirational work, but Reactive was created for differing
reasons.  More detailed write-ups of the trade-offs to come!

- Any of the multitude of declarative UI toolkits based on reactive
  programming, especially those in the Haskell universe.

- Specifically in JS land: [Knockout] in terms of the mechanics behind
  observables.

- [Angular] is a popular framework that emphasizes testability that extends
  HTML with its own directives.  Unfortunately it employs a ton of magic and
  has a steep learning curve.  As Khan Academy's Ben Alpert put it:

  > Angular documentation for how to write a directive (a reusable component)
  > needs to explain directive priorities, the difference between compiling and
  > linking, the creation of new scopes, and transclusion, all of which are
  > Angular-specific concepts.

- [Ember] offers its own template language that feels right at home if you are
  coming from a server-side templates background.

- [Polymer] for its brazen use of new but unstable technologies such as
  `Object.observe`, Web Components, and Shadow DOM.  Some good ideas here, but
  there's still a good deal of platform/tooling immaturity as well as more
  verbose scaffolding around creating components and defining reactive
  behaviors

- [React] shares a similar approach of leveraging a full programming language
  (JS) rather than a more restrictive template language for declaratively
  assembling UI components, as well as a similar focus on only one-way data
  bindings, as contributor Lee Byron describes:

  > React was born out of frustrations with the common pattern of writing
  > two-way data bindings in complex MVC apps. React is an implementation of
  > one-way data bindings.

  React also encourages use of JSX, which is a syntactic transform over JS.

  It imposes a more heavyweight component model with a more complex API that
  has a greater surface area.  There are a number of core concepts to learn:
  properties, refs, state, "classes", mixins, lifecycle management
  (`component[Will|Did]Mount`, `unmountAndReleaseReactRootNode`, etc.),
  property transfer, controlling update propagation (`shouldComponentUpdate`,
  `componentWillReceiveProps`, etc.), and more.

  React also requires its own way of doing things such as low-level DOM
  manipulation—something that Reactive intentionally delegates elsewhere, as
  there already exist well-established libraries for these domains.

  Lastly, React needs to compute diffs between states and between rendered DOMs.
  This won't make a difference in many areas, but latency does unfortunately
  matter in some, e.g. when you're trying to produce smooth reactions to mouse
  move/drag events (without "breaking out" of the framework).

  Feel free to dig into our clone of the React tutorial, under
  `examples/react-tut/`.

- [Visage], formerly known as JavaFX, introduces incremental evaluation in a
  statically typed scripting language for the JVM.  It focuses on building
  Swing UIs.  Reactive was actually originally inspired by its approach, which
  is also one of using a full programming language to host the declarative UI
  construction, along with its intuitive syntax for creating bindings.  JavaFX
  used compile-time transforms to implement incremental evaluation.

- [CoffeeKup] is another CoffeeScript-embedded DSL for constructing (static)
  DOMs

[CoffeeKup]: https://github.com/mauricemach/coffeekup
[Knockout]: http://knockoutjs.com
[Ember]: http://emberjs.com
[Angular]: http://angularjs.org
[Visage]: http://code.google.com/p/visage
[Polymer]: http://www.polymer-project.org/
[React]: http://facebook.github.io/react/
