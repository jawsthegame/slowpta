getJSON = require('jqueryify').getJSON


class SeptaAPI
  @urlRoot: 'http://www3.septa.org/hackathon/'

  @getStops: (route) ->
    url = "#{SeptaAPI.urlRoot}Stops/?req1=#{route}&callback=?"
    getJSON url

  @getSchedule: (stopId, route) ->
    scheduleUrl = "#{SeptaAPI.urlRoot}BusSchedules/" \
      + "?req1=#{stopId}&req2=#{route}&req6=1&callback=?"
    getJSON scheduleUrl

  @getBusLocations: (route) ->
    url = "#{SeptaAPI.urlRoot}TransitView/?route=#{route}&callback=?"
    getJSON url


module.exports = SeptaAPI
