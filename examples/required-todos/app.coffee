define ['domReady!', 'jquery', 'reactive-coffee', 'views/todoApp'], (
        document, $, rx, todoApp) ->
  tasks = rx.array()
  window.tasks = tasks

  $('body').prepend(todoApp(tasks))
