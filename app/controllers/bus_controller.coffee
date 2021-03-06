Quips       = require 'quips'
_           = require 'underscore'
jQuery      = require 'jqueryify'

TravelMode  = google.maps.TravelMode
Deferred    = jQuery.Deferred
get         = jQuery.get

BusMapView        = require 'views/bus/map'
BusSelectorView   = require 'views/bus/selector'
Direction         = require('lib/routes').Direction
GoogleDistanceAPI = require 'lib/google_distance_api'
SeptaAPI          = require 'lib/septa_api'


blockCss =
  padding: '30px'
  margin: '0 0 0 -30px'

class BusController extends Quips.Controller
  layout: require 'templates/bus/layout'

  routes:
    '':                 'showSelector'
    ':route/:direction': 'renderMap'

  views:
    '#map':       'mapView'
    '#selector':  'selectorView'

  events:
    'mapView.mapped':   'mapped'
    'mapView.refresh':  'refresh'

  constructor: ->
    @busInfos = []
    @busMarkers = []
    @urlRoot = 'http://www3.septa.org/hackathon/'

    @mapView = new BusMapView().render()
    @selectorView = new BusSelectorView().render()

    super

  showSelector: ->
    @mapView.hide()
    @selectorView.show()

  renderMap: (@route, direction) ->
    @activate()
    @selectorView.hide()
    @mapView.show()
    @direction = Direction[direction.toUpperCase()]

    @home = new google.maps.LatLng(39.952681,-75.163743)
    navigator.geolocation.getCurrentPosition (position) =>
      @home = new google.maps.LatLng(
        position.coords.latitude,
        position.coords.longitude)

    @mapView.drawMap(@home, @route, @direction)

  mapped: (@map) ->
    if not /iPhone|iPod|iPad|Android|BlackBerry/.test navigator.userAgent
      google.maps.event.addListener @map, 'click', (event) =>
        @home = event.latLng
        @mapView.drawMap(@home, @route, @direction)
    @bounds = new google.maps.LatLngBounds
    @_mapBusRoute(@map)
    @_addStopAndBuses(@map)

  refresh: ->
    if @stop? and @map?
      @mapView.block message: 'Refreshing buses...', css: blockCss
      @_updateBuses(@map, @stop).always => @mapView.unblock()
    else
      @mapView.drawMap(@home, @route, @direction)

  _addStopAndBuses: (map) ->
    @_findNearestStop().done (@stop) =>
      stopMarker = new google.maps.Marker
        position: @stop.point
        map: map
      stopTemplate = require 'templates/bus/stop_tooltip'
      @stopInfo = new google.maps.InfoWindow
        content: stopTemplate(@stop)
      google.maps.event.addListener stopMarker, 'click', =>
        @_closeInfoWindows()
        @stopInfo.open(map, stopMarker)
      @bounds.extend(@stop.point)
      map.setCenter(@stop.point)
      @_updateBuses(map, @stop)

  _updateBuses: (map, stop) ->
    deferred = Deferred()
    @_getBusLocations(stop.point)
      .done (locations) =>
        if locations.length
          GoogleDistanceAPI.calculate(stop.point, locations, TravelMode.DRIVING)
            .done (buses) =>
              @_clearBuses()
              @_addBuses(map, stop, locations, buses)
              deferred.resolve()
            .fail -> deferred.reject()
      .fail -> deferred.reject()

    deferred.promise()

  _clearBuses: ->
    for marker in @busMarkers
      marker.setMap(null)
    @busMarkers = []

  _addBuses: (map, stop, locations, buses) ->
    sortedBuses = _.sortBy buses, (b) -> b.travelSec
    for bus, i in sortedBuses
      offset = locations[i].offset
      min = bus.travelSec / 60
      minUntil = min - parseInt(offset) - 1 # be careful, it's SEPTA
      minUntil = 0 if minUntil < 0
      if minUntil
        do (minUntil) =>
          minToStop = stop.travelSec / 60
          icon = if minUntil < minToStop + 1
            'bus_red'
          else if minUntil < minToStop + 3
            'bus_yellow'
          else if minUntil < minToStop + 10
            'bus_green'
          else
            'bus'
          busMarker = new google.maps.Marker
            position: bus.point
            map: map
            icon: "images/#{icon}.png"
          @busMarkers.push busMarker
          busTemplate = require 'templates/bus/bus_tooltip'
          busInfo = new google.maps.InfoWindow
            content: busTemplate
              direction: @direction
              route: @route
              minUntil: minUntil.toFixed(2)
              minToStop: minToStop.toFixed(2)
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

  _findNearestStop: ->
    deferred = Deferred()
    @mapView.block message: 'Finding nearest bus stop...', css: blockCss
    SeptaAPI.getStops(@route)
      .done (data) =>
        @_processStops(data)
          .done (stops) =>
            GoogleDistanceAPI.calculate(@home, stops, TravelMode.WALKING)
              .done (stops) ->
                sortedStops = _.sortBy stops, (b) -> b.travelSec
                deferred.resolve(sortedStops[0])
              .fail ->
                deferred.reject()
                @mapView.unblock()
          .fail ->
            deferred.reject()
          .always =>
            @mapView.unblock()
      .fail ->
        @mapView.unblock()
        deferred.reject()

    deferred.promise()

  _processStops: (stopData) ->
    deferred = Deferred()
    @_doDirectionChecks(stopData, 1, 8, deferred)
    deferred.promise()

  _doDirectionChecks: (stopData, pass, passes, deferred) ->
    # Recursively call this to do a pass in each 1/4 mile circle around
    # the current location to find the closest stop. Max 2 miles.
    directionChecks = []

    if pass <= passes
      for stop in stopData
        stopPoint = new google.maps.LatLng(stop.lat, stop.lng)
        if @_checkDistanceBounds(@home, stopPoint, 0.25 * pass)
          directionChecks.push @_augmentStop(stop)

      jQuery.when.apply(jQuery, directionChecks).done (results...) =>
        matches = (r for r in results when r.direction is Direction.get(@direction))
        if matches.length
          deferred.resolve(matches)
        else
          @_doDirectionChecks(stopData, pass+1, passes, deferred)
    else
      deferred.reject()

    deferred

  _augmentStop: (stop) ->
    deferred = Deferred()
    SeptaAPI.getSchedule(stop.stopid, @route)
      .done (schedule) =>
        stopPoint = new google.maps.LatLng(stop.lat, stop.lng)
        deferred.resolve
          point:      stopPoint
          name:       jQuery('<div>').html(stop.stopname).text()
          direction:  schedule[@route][0]['Direction']
          next:       schedule[@route][0]['date']
      .fail -> deferred.reject()

    deferred.promise()

  _getBusLocations: (from) ->
    deferred = Deferred()
    SeptaAPI.getBusLocations(@route)
      .done (data) =>
        locations = []
        for row in data['bus']
          to = new google.maps.LatLng(row.lat, row.lng)
          if row['Direction'] is @direction and @_checkDirectionBounds(from, to)
            locations.push
              point: to
              offset: row['Offset']
        deferred.resolve locations
      .fail -> deferred.reject()

    deferred.promise()

  _checkDirectionBounds: (from, to) ->
    (@direction is Direction.NORTH and from.lat() > to.lat()) \
      or (@direction is Direction.SOUTH and from.lat() < to.lat()) \
      or (@direction is Direction.EAST and from.lng() > to.lng()) \
      or (@direction is Direction.WEST and from.lng() < to.lng())

  _checkDistanceBounds: (from, to, maxDist) ->
    if maxDist
      miles = @_great_circle from, to
      return miles < maxDist

    true

  _great_circle: (from, to) ->
    degrees_to_radians = Math.PI / 180
    A_lat = from.lat() * degrees_to_radians
    B_lat = to.lat() * degrees_to_radians
    d_lon = Math.abs(to.lng() - from.lng()) * degrees_to_radians

    Math.atan2(
      Math.sqrt(
        Math.pow(Math.cos(B_lat) * Math.sin(d_lon), 2.0) + \
        Math.pow(Math.cos(A_lat) * Math.sin(B_lat) - Math.sin(A_lat) \
          * Math.cos(B_lat) * Math.cos(d_lon), 2.0)),
      Math.sin(A_lat) * Math.sin(B_lat) + Math.cos(A_lat) * Math.cos(B_lat) \
        * Math.cos(d_lon)
    ) * 3959.9


module.exports = BusController
