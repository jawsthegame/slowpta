Quips     = require 'quips'
$         = require 'jqueryify'
Backbone  = require 'backbone'

BusController   = require 'controllers/bus_controller'


class App

  constructor: ->
    @showUI()

  showUI: ->
    $layout = $('body').empty().append(require 'templates/layout')
    $content = $layout.find('#main-content')

    new BusController(el: $content).activate()

    Backbone.history.start()


module.exports = App
