bobtail [![Build Status](https://secure.travis-ci.org/yang/reactive-coffee.png?branch=master)](https://travis-ci.org/inferinc/bobtail) [![Bower version](https://badge.fury.io/bo/reactive-coffee.svg)](http://badge.fury.io/bo/reactive-coffee)
===============

A lightweight CoffeeScript library/DSL for [reactive programming] and for
declaratively building scalable web UIs.

See the [website], which has an overview, tutorial, comparisons, and more.

[reactive programming]: http://en.wikipedia.org/wiki/Reactive_programming
[website]: http://bobtailjs.io

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

```javascript
class Task {
  constructor(descrip, priority, isDone) {
    this.descrip = rx.cell(descrip);
    this.priority = rx.cell(priority);
    this.isDone = rx.cell(isDone);
  }
}

const tasks = rx.array([
  new Task('Get milk', 'important', false),
  new Task('Play with Reactive Coffee', 'critical', false),
  new Task('Walk the dog', 'meh', false)
]);

// Our main view: a checklist of tasks, a button to add a new task, and a task
// editor component (defined further down).

const main = function() {
  const currentTask = rx.cell(tasks.at(0)); // "View model" of currently selected task

  return $('body').append(
    div({class: 'task-manager'}, [
      h1(x.bind(() => [`${tasks.length()} task(s) for today`])),
      ul({class: 'tasks'}, tasks.map(function(task) {
        return li({class: 'task'}, [
          input({type: 'checkbox', init() { return this.change(() => task.isDone.set(this.is(':checked'))); }}),
          span({class: 'descrip'}, rx.bind(() => `${task.descrip.get()} (${task.priority.get()})`)),
          a({href: 'javascript: void 0', init() { return this.click(() => currentTask.set(task)); }}, 'Edit')
        ]);})),
      button({init() { return this.click(() => tasks.push(new Task('Task', 'none', false))); }}, [
        'Add new task'
      ]),
      taskEditor({
        task: rx.bind(() => currentTask.get()),
        onSubmit(descrip, priority) {
          currentTask.get().descrip.set(descrip);
          return currentTask.get().priority.set(priority);
        }
      })
    ])
  );
};

// The task editor demonstrates how to define a simple component.

var taskEditor = function(opts) {
  let descrip, priority;
  const task = () => opts.task.get();
  const theForm = form({}, [
    h2('Edit Task'),
    label('Description'),
    (descrip = input({type: 'text', value: rx.bind(() => task().descrip.get())})),
    br(),
    label('Priority'),
    (priority = input({type: 'text', value: rx.bind(() => task().priority.get())})),
    br(),
    label('Status'),
    span(rx.bind(() => [task().isDone.get() ? 'Done' : 'Not done'])),
    br(),
    button('Update')
  ]);
  return theForm.submit(function() {
    opts.onSubmit(descrip.val().trim(), priority.val().trim());
    this.reset();
    return false;
  });
};

$(main);
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

# Mascot
Charlie the Bobtail designed by Adele Boulie.
