Deferred = require('jqueryify').Deferred


class GoogleDistanceAPI

  @calculate: (origin, destinations, mode) ->
    deferred = Deferred()
    lat = origin.lat()
    lng = origin.lng()

    service = new google.maps.DistanceMatrixService
    service.getDistanceMatrix
      origins: [origin]
      destinations: (d.point for d in destinations)
      travelMode: mode
      unitSystem: google.maps.UnitSystem.IMPERIAL
      avoidHighways: true
      avoidTolls: true
      , (response, status) ->
        if status is google.maps.DistanceMatrixStatus.OK
          locations = []
          for e, i in response.rows[0].elements
            locations.push
              point: destinations[i].point
              travelSec: e.duration.value
              next: destinations[i].next # only exists for stops
              name: destinations[i].name \
                or response.destinationAddresses[i]

          deferred.resolve(locations)
        else
          console.log status
          deferred.reject()

    deferred.promise()


module.exports = GoogleDistanceAPI
