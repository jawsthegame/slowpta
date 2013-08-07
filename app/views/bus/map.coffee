Quips = require 'quips'


class BusMapView extends Quips.View
  template: require 'templates/bus/map'

  elements:
    '#map-canvas': '$canvas'
    '#route-info': '$routeInfo'

  drawMap: (center, route, direction) ->
    map = new google.maps.Map @$canvas[0],
      center: center
      zoom: 14
      mapTypeId: google.maps.MapTypeId.ROADMAP

    @trigger 'mapped', map
    @$routeInfo.text("Route #{route} #{direction}")

  show: ->
    @$el.parent().removeClass 'hidden'

  hide: ->
    @$el.parent().addClass 'hidden'


module.exports = BusMapView
