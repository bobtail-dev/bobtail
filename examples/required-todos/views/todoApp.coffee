define ['reactive-coffee', 'task'], (rx, Task) ->
  (tasks) ->
    incomplete = ->
      (task for task in tasks.all() when not task.isCompleted.get()).length


    {section, header, footer, h1, div, span
    strong, input, button, label, ul, li} = rx.rxt.tags
    # can also do rx.rxt.importTags() at this or higher level
    # to bring all into global scope
    bind = rx.bind

    section {id: 'todoapp'}, [
      header {id: 'header'}, [
        h1 'todos'
        input {
          id: 'new-todo'
          type: 'text'
          placeholder: 'What needs to be done?'
          autofocus: true
          keydown: (e) ->
            if e.which == 13
              tasks.push(new Task(@val().trim()))
              @val('')
              false # In IE, don't set focus on the `button` (crazy!)
              # <http://stackoverflow.com/questions/12325066/button-click-event-fires-when-pressing-enter-key-in-different-input-no-forms>
        }
      ]
      div bind ->
        if tasks.length() == 0
          []
        else
          [
            section {id: 'main'}, [
              input {
                id: 'toggle-all'
                type: 'checkbox'
                change: ->
                  for task in tasks.all()
                    task.isCompleted.set(@is(':checked'))
              }
              label {for: 'toggle-all'}, 'Mark all as complete'
              ul {id: 'todo-list'}, tasks.map (task) ->
                editBox = null
                li {
                  class: bind -> [
                    'completed' if task.isCompleted.get()
                    'editing' if task.isEditing.get()
                  ].filter((x) -> x?).join(' ')
                }, bind ->
                  if task.isEditing.get() then [
                    editBox = input {
                      type: 'text'
                      class: 'edit'
                      autofocus: true
                      value: task.title.get()
                      keyup: (e) ->
                        if e.which == 13
                          @blur()
                      blur: ->
                        task.title.set(@val())
                        task.isEditing.set(false)
                    }
                  ] else [
                    input {
                      class: 'toggle'
                      type: 'checkbox'
                      checked: bind -> task.isCompleted.get()
                      change: -> task.isCompleted.set(@is(':checked'))
                    }
                    label {
                      dblclick: ->
                        task.isEditing.set(true)
                        editBox.focus()
                    }, bind -> "#{task.title.get()}"
                    button {
                      class: 'destroy'
                      click: -> tasks.remove(task)
                    }
                  ]
            ]
            footer {id: 'footer'}, [
              span {id: 'todo-count'}, bind -> [
                strong "#{incomplete()}"
                if incomplete() == 1 then ' item left' else ' items left'
              ]
              button {
                id: 'clear-completed'
                click: ->
                  tasks.replace(task for task in tasks.all() when not task.isCompleted.get())
              }, 'Clear completed'
            ]
          ]
    ]
