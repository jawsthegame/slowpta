Quips     = require 'quips'
_         = require 'underscore'
jQuery    = require 'jqueryify'
getJSON   = jQuery.getJSON
Deferred  = jQuery.Deferred

BusMapView = require 'views/bus/map'


Direction =
 NORTH: 'NorthBound'
 SOUTH: 'SouthBound'
 EAST:  'EastBound'
 WEST:  'WestBound'

class BusController extends Quips.Controller
  layout: require 'templates/bus/layout'

  routes:
    ':route/:direction': 'renderMap'

  views:
    '#map': 'mapView'

  events:
    'mapView.mapped': 'mapped'

  constructor: ->
    @mapView = new BusMapView().render()
    @home = new google.maps.LatLng(39.952681,-75.163743)
    navigator.geolocation.getCurrentPosition (position) =>
      @home = new google.maps.LatLng(position.coords.latitude, position.coords.longitude)
    super

  renderMap: (@route, direction) ->
    @direction = Direction[direction.toUpperCase()]
    @mapView.drawMap(@home)
    # setInterval (=> @mapView.drawMap()), 30000

  mapped: (map) ->
    @bounds = new google.maps.LatLngBounds
    @_mapBusRoute(map)
    @_getNearestStop().done (stop) =>
      stopMarker = new google.maps.Marker
        position: stop.point
        map: map
      stopInfo = new google.maps.InfoWindow
        content: "Nearest Stop<br/><small>#{stop.name}</small>"
      google.maps.event.addListener stopMarker, 'click', -> stopInfo.open(map, stopMarker)
      @bounds.extend(stop.point)
      map.setCenter(stop.point)

      @_getBusLocations(stop.point).done (locations) =>
        if locations
          points = (l.point for l in locations)
          @_calculateDistances(stop.point, points, google.maps.TravelMode.DRIVING).done (buses) =>
            for bus, i in buses
              offset = locations[i].offset
              min = bus.travelSec / 60
              minUntil = min - parseInt(offset)
              if minUntil
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
                google.maps.event.addListener busMarker, 'click', -> busInfo.open(map, busMarker)
                @bounds.extend(bus.point)
                map.fitBounds(@bounds)

  _mapBusRoute: (map) ->
    routeLayer = new google.maps.KmlLayer
      url: "http://www3.septa.org/transitview/kml/#{@route}.kml"
      suppressInfoWindows: true
      preserveViewport: true
    routeLayer.setMap(map)

  _getNearestStop: ->
    deferred = Deferred()
    getJSON "http://www3.septa.org/hackathon/Stops/?req1=#{@route}&callback=?", (data) =>
      stops = []
      for stop in data
        stopPoint = new google.maps.LatLng(stop.lat, stop.lng)
        if @_checkBounds(@home, stopPoint, 0.5)
          stops.push stopPoint
      @_calculateDistances(@home, stops, google.maps.TravelMode.WALKING).done (stops) ->
        sortedStops = _.sortBy stops, (b) -> b.travelSec
        deferred.resolve(sortedStops[0])

    deferred.promise()

  _getBusLocations: (from) ->
    deferred = Deferred()
    getJSON "http://www3.septa.org/hackathon/TransitView/?route=#{@route}&callback=?", (data) =>
      locations = []
      for row in data['bus']
        to = new google.maps.LatLng(row.lat, row.lng)
        if row['Direction'] is @direction and @_checkBounds(from, to)
          locations.push
            point: to
            offset: row['Offset']
      deferred.resolve locations

    deferred.promise()

  _checkBounds: (from, to, maxDist) ->
    inBounds = (@direction is Direction.NORTH and from.lat() > to.lat()) \
      or (@direction is Direction.SOUTH and from.lat() < to.lat()) \
      or (@direction is Direction.EAST and from.lng() > to.lng()) \
      or (@direction is Direction.WEST and from.lng() < to.lng())

    if maxDist
      deg = (1 / 69.047) * maxDist
      latDiff = Math.abs(from.lat() - to.lat())
      lngDiff = Math.abs(from.lng() - to.lng())
      return latDiff < deg and lngDiff < deg and inBounds

    inBounds

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
          deferred.reject()

    deferred.promise()


module.exports = BusController
