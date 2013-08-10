Quips = require 'quips'


class BusMapView extends Quips.View
  template: require 'templates/bus/map'

  elements:
    '#map-canvas': '$canvas'
    '#route-info': '$routeInfo'

  events:
    'click #refresh': 'refresh'

  drawMap: (center, route, direction) ->
    map = new google.maps.Map @$canvas[0],
      center: center
      zoom: 14
      mapTypeId: google.maps.MapTypeId.ROADMAP
      panControl: false
      streetViewControl: false
      overviewMapControl: false
      zoomControl: false
      mapTypeControl: false

    @trigger 'mapped', map
    @$routeInfo.text("Route #{route} #{direction}")

  show: ->
    @$el.parent().removeClass 'hidden'

  hide: ->
    @$el.parent().addClass 'hidden'

  refresh: ->
    @trigger 'refresh'


module.exports = BusMapView
