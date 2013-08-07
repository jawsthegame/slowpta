Quips = require 'quips'


class BusMapView extends Quips.View
  template: require 'templates/bus/map'

  elements:
    '#map-canvas': '$canvas'

  drawMap: (center) ->
    map = new google.maps.Map @$canvas[0],
      center: center
      zoom: 14
      mapTypeId: google.maps.MapTypeId.ROADMAP

    @trigger 'mapped', map


module.exports = BusMapView
