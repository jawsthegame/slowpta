Quips       = require 'quips'
_           = require 'underscore'
jQuery      = require 'jqueryify'
getJSON     = jQuery.getJSON
Deferred    = jQuery.Deferred
TravelMode  = google.maps.TravelMode

BusMapView      = require 'views/bus/map'
BusSelectorView = require 'views/bus/selector'
Direction       = require('lib/routes').Direction


class BusController extends Quips.Controller
  layout: require 'templates/bus/layout'

  routes:
    '':                 'showSelector'
    ':route/:direction': 'renderMap'

  views:
    '#map':       'mapView'
    '#selector':  'selectorView'

  events:
    'mapView.mapped': 'mapped'

  constructor: ->
    @mapView = new BusMapView().render()
    @selectorView = new BusSelectorView().render()

    @home = new google.maps.LatLng(39.952681,-75.163743)
    navigator.geolocation.getCurrentPosition (position) =>
      @home = new google.maps.LatLng(
        position.coords.latitude,
        position.coords.longitude)
    super

  showSelector: ->
    @mapView.hide()
    @selectorView.show()

  renderMap: (@route, direction) ->
    @activate()
    @selectorView.hide()
    @mapView.show()
    @direction = Direction[direction.toUpperCase()]
    @mapView.drawMap(@home)
    # setInterval (=> @mapView.drawMap()), 30000

  mapped: (map) ->
    google.maps.event.addListener map, 'click', (event) =>
      @home = event.latLng
      @mapView.drawMap(@home)
    @bounds = new google.maps.LatLngBounds
    @_mapBusRoute(map)
    @_getNearestStop().done (stop) =>
      stopMarker = new google.maps.Marker
        position: stop.point
        map: map
      @stopInfo = new google.maps.InfoWindow
        content: "Nearest Stop<br/><small>#{stop.name}</small>"
      google.maps.event.addListener stopMarker, 'click', =>
        @_closeInfoWindows()
        @stopInfo.open(map, stopMarker)
      @bounds.extend(stop.point)
      map.setCenter(stop.point)

      @_getBusLocations(stop.point).done (locations) =>
        if locations
          points = (l.point for l in locations)
          @_calculateDistances(stop.point, points, TravelMode.DRIVING)
            .done (buses) =>
              @busInfos = []
              sortedBuses = _.sortBy buses, (b) -> b.travelSec
              for bus, i in sortedBuses
                offset = locations[i].offset
                min = bus.travelSec / 60
                minUntil = min - parseInt(offset)
                if minUntil
                  do (minUntil) =>
                    busMarker = new google.maps.Marker
                      position: bus.point
                      map: map
                      icon: 'images/bus.png'
                    busTemplate = require 'templates/bus/bus_tooltip'
                    busInfo = new google.maps.InfoWindow
                      content: busTemplate
                        direction: @direction
                        route: @route
                        minUntil: minUntil.toFixed(2)
                    @busInfos.push busInfo
                    do (busMarker) =>
                      google.maps.event.addListener busMarker, 'click', =>
                        @_closeInfoWindows()
                        busInfo.open(map, busMarker)
                    @bounds.extend(bus.point) if i is 0
              map.fitBounds(@bounds)

  _closeInfoWindows: ->
    if @stopInfo? then @stopInfo.close()
    busInfo.close() for busInfo in @busInfos

  _mapBusRoute: (map) ->
    routeLayer = new google.maps.KmlLayer
      url: "http://www3.septa.org/transitview/kml/#{@route}.kml"
      suppressInfoWindows: true
      preserveViewport: true
    routeLayer.setMap(map)

  _getNearestStop: ->
    deferred = Deferred()
    url = "http://www3.septa.org/hackathon/Stops/?req1=#{@route}&callback=?"
    getJSON url, (data) =>
      stops = []
      for stop in data
        stopPoint = new google.maps.LatLng(stop.lat, stop.lng)
        if @_checkDistanceBounds(@home, stopPoint, 0.5)
          stops.push stopPoint
      @_calculateDistances(@home, stops, TravelMode.WALKING).done (stops) ->
        sortedStops = _.sortBy stops, (b) -> b.travelSec
        deferred.resolve(sortedStops[0])

    deferred.promise()

  _getBusLocations: (from) ->
    deferred = Deferred()
    url =
      "http://www3.septa.org/hackathon/TransitView/?route=#{@route}&callback=?"
    getJSON url, (data) =>
      locations = []
      for row in data['bus']
        to = new google.maps.LatLng(row.lat, row.lng)
        if row['Direction'] is @direction and @_checkDirectionBounds(from, to)
          locations.push
            point: to
            offset: row['Offset']
      deferred.resolve locations

    deferred.promise()

  _checkDirectionBounds: (from, to) ->
    (@direction is Direction.NORTH and from.lat() > to.lat()) \
      or (@direction is Direction.SOUTH and from.lat() < to.lat()) \
      or (@direction is Direction.EAST and from.lng() > to.lng()) \
      or (@direction is Direction.WEST and from.lng() < to.lng())

  _checkDistanceBounds: (from, to, maxDist) ->
    if maxDist
      deg = (1 / 69.047) * maxDist
      latDiff = Math.abs(from.lat() - to.lat())
      lngDiff = Math.abs(from.lng() - to.lng())
      return latDiff < deg and lngDiff < deg

    true

  _calculateDistances: (point, locations, mode) ->
    deferred = Deferred()
    lat = point.lat()
    lng = point.lng()

    service = new google.maps.DistanceMatrixService
    service.getDistanceMatrix
      origins: [point]
      destinations: locations
      travelMode: mode
      unitSystem: google.maps.UnitSystem.IMPERIAL
      avoidHighways: false
      avoidTolls: false
      , (response, status) ->
        if status is google.maps.DistanceMatrixStatus.OK
          buses = []
          for e, i in response.rows[0].elements
            buses.push
              point: locations[i]
              travelSec: e.duration.value
              name: response.destinationAddresses[i]

          deferred.resolve(buses)
        else
          console.log status
          deferred.reject()

    deferred.promise()


module.exports = BusController
