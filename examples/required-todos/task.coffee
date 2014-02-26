define ['reactive-coffee'], (rx)->
  class Task
    constructor: (title) ->
      @title = rx.cell(title)
      @isEditing = rx.cell(false)
      @isCompleted = rx.cell(false)
