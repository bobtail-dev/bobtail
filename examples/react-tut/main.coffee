# Based on <https://github.com/petehunt/react-tutorial/blob/master/scripts/example.js>

bind = rx.bind
lagBind = rx.lagBind

rxt.importTags()

mdConverter = new Showdown.converter()

markdown = (x) -> rxt.rawHtml(mdConverter.makeHtml(x))

Comment = (args) ->
  div {class: 'comment'}, [
    h2 {class: 'commentAuthor'}, [args.author]
    span {}, [markdown(args.text)]
  ]

CommentList = (args) ->
  div {class: 'commentList'}, args.comments.map (comment) ->
    Comment({author: comment.author, text: comment.text})

CommentForm = (args) ->
  $form = form {name: 'commentForm', class: 'commentForm'}, [
    $name = input {type: 'text', placeholder: 'Your name'}
    $text = input {type: 'text', placeholder: 'Say something...'}
    input {type: 'submit', value: 'Post'}
  ]
  $form.submit ->
    [name, text] = ($x.val().trim() for $x in [$name, $text])
    return false if name == '' or text == ''
    args.onCommentSubmit({author: name, text: text})
    $x.val('') for $x in [$name, $text]
    false
  $form

CommentBox = (args) ->
  comments = rx.array([])
  loadCommentsFromServer = ->
    $.ajax({
      url: args.url
      success: (data) -> comments.replace(data.comments)
      error: -> console.log(arguments)
    })
  setInterval(loadCommentsFromServer, args.pollInterval)
  handleCommentSubmit = (comment) ->
    comments.push(comment)
    $.ajax({
      url: args.url
      type: 'POST'
      data: comment
      success: (data) -> comments.replace(data.comments)
    })
  $base = div {class: 'commentBox'}, [
    h1 {}, ['Comments']
    CommentList {comments: comments}
    CommentForm {onCommentSubmit: handleCommentSubmit}
  ]
  $base

$('#container').append(CommentBox {url: 'comments.json', pollInterval: 2000})
