require
  urlArgs: "b=#{(new Date()).getTime()}"
  paths:
    underscore: 'bower_components/underscore/underscore'
    jquery: 'bower_components/jquery/dist/jquery'
    'reactive-coffee': 'bower_components/reactive-coffee/dist/reactive-coffee'
    domReady: 'bower_components/requirejs-domready/domReady'

require ['app'], () ->
  # load and run app
