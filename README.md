reactive.coffee [![Build Status](https://secure.travis-ci.org/yang/reactive-coffee.png?branch=master)](https://travis-ci.org/yang/reactive-coffee) [![Bower version](https://badge.fury.io/bo/reactive-coffee.svg)](http://badge.fury.io/bo/reactive-coffee)
===============

A lightweight CoffeeScript library/DSL for [reactive programming] and for
declaratively building scalable web UIs.

See the [website], which has an overview, tutorial, comparisons, and more.

[reactive programming]: http://en.wikipedia.org/wiki/Reactive_programming
[website]: http://yang.github.io/reactive-coffee/

Highlights
----------

- Library of reactive programming primitives
- Declarative DOM construction
- Scalable in both performance and application architecture
- Simple, no magic, no new template language, all CoffeeScript
- Tested with Chrome, Firefox, Safari, and IE10
- Available via [Bower] and [cdnjs]
- Works with jQuery
- MIT license

[Bower]: http://bower.io/
[cdnjs]: http://cdnjs.com/
[fiddle]: http://jsfiddle.net/yang/SGvuy/

Example: To-Do List
-------------------

You can [play with this example on jsFiddle][fiddle], see a [complete
TodoMVC example][TodoMVC], or head directly to the [tutorial].

```coffeescript
# This is our core data model, an array of Task objects.

class Task
  constructor: (descrip, priority, isDone) ->
    @descrip = rx.cell(descrip)
    @priority = rx.cell(priority)
    @isDone = rx.cell(isDone)

tasks = rx.array([
  new Task('Get milk', 'important', false)
  new Task('Play with Reactive Coffee', 'critical', false)
  new Task('Walk the dog', 'meh', false)
])

# Our main view: a checklist of tasks, a button to add a new task, and a task
# editor component (defined further down).

main = ->
  currentTask = rx.cell(tasks.at(0)) # "View model" of currently selected task

  $('body').append(
    div {class: 'task-manager'}, [
      h1 {}, bind -> ["#{tasks.length()} task(s) for today"]
      ul {class: 'tasks'}, tasks.map (task) ->
        li {class: 'task'}, [
          input {type: 'checkbox', init: -> @change => task.isDone.set(@is(':checked'))}
          span {class: 'descrip'}, bind -> [
            "#{task.descrip.get()} (#{task.priority.get()})"
          ]
          a {href: 'javascript: void 0', init: -> @click => currentTask.set(task)}, [
            'Edit'
          ]
        ]
      button {init: -> @click => tasks.push(new Task('Task', 'none', false))}, [
        'Add new task'
      ]
      taskEditor {
        task: bind -> currentTask.get()
        onSubmit: (descrip, priority) ->
          currentTask.get().descrip.set(descrip)
          currentTask.get().priority.set(priority)
      }
    ]
  )

# The task editor demonstrates how to define a simple component.

taskEditor = (opts) ->
  task = -> opts.task.get()
  theForm = form {}, [
    h2 {}, ['Edit Task']
    label {}, ['Description']
    descrip = input {type: 'text', value: bind -> task().descrip.get()}
    br {}
    label {}, ['Priority']
    priority = input {type: 'text', value: bind -> task().priority.get()}
    br {}
    label {}, ['Status']
    span {}, bind -> [if task().isDone.get() then 'Done' else 'Not done']
    br {}
    button {}, ['Update']
  ]
  theForm.submit ->
    opts.onSubmit(descrip.val().trim(), priority.val().trim())
    @reset()
    false

$(main)
```

[TodoMVC]: https://github.com/yang/reactive-coffee/blob/master/examples/todomvc/index.jade

Next steps
----------

See more [quickstart examples][quickstart], read through the
[tutorial][tutorial], or learn more about the [motivation and design
rationale][design].

[quickstart]: http://yang.github.io/reactive-coffee/quickstart.html
[tutorial]: http://yang.github.io/reactive-coffee/tutorial.html
[design]: http://yang.github.io/reactive-coffee/design.html
[related]: http://yang.github.io/reactive-coffee/related.html

