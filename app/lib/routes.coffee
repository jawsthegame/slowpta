_ = require 'underscore'


Direction =
 NORTH: 'NorthBound'
 SOUTH: 'SouthBound'
 EAST:  'EastBound'
 WEST:  'WestBound'


class Route
  constructor: (@num, @in, @out) ->
    @friendlyIn   = @_friendly(@in)
    @friendlyOut  = @_friendly(@out)
    @enumIn       = _.invert(Direction)[@in]
    @enumOut      = _.invert(Direction)[@out]

  _friendly: (direction) ->
    direction.replace 'Bound', ''


routes = [
  new Route(5,      Direction.NORTH,  Direction.SOUTH)
  new Route(7,      Direction.NORTH,  Direction.SOUTH)
  new Route(9,      Direction.WEST,   Direction.EAST)
  new Route(12,     Direction.WEST,   Direction.EAST)
  new Route(15,     Direction.WEST,   Direction.EAST)
  new Route(17,     Direction.NORTH,  Direction.SOUTH)
  new Route(21,     Direction.WEST,   Direction.EAST)
  new Route(23,     Direction.NORTH,  Direction.SOUTH)
  new Route(33,     Direction.NORTH,  Direction.SOUTH)
  new Route(40,     Direction.WEST,   Direction.EAST)
  new Route(42,     Direction.WEST,   Direction.EAST)
  new Route(43,     Direction.WEST,   Direction.EAST)
  new Route(47,     Direction.NORTH,  Direction.SOUTH)
  new Route('47M',  Direction.NORTH,  Direction.SOUTH)
  new Route(48,     Direction.WEST,   Direction.EAST)
  new Route(57,     Direction.NORTH,  Direction.SOUTH)
]


module.exports =
  Direction:  Direction
  Route:      Route
  routes:     routes
