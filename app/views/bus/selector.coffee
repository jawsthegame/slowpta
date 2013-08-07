Quips = require 'quips'

routes = require('lib/routes').routes


class BusSelectorView extends Quips.View
  template: ->
    tmpl = require 'templates/bus/selector'
    tmpl routes: routes

  show: ->
    @$el.parent().removeClass 'hidden'

  hide: ->
    @$el.parent().addClass 'hidden'


module.exports = BusSelectorView
