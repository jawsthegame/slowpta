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
    direction.replace 'B', '-B'


routes = [
  new Route(5,  Direction.NORTH,  Direction.SOUTH),
  new Route(21, Direction.EAST,   Direction.WEST),
  new Route(23, Direction.NORTH,  Direction.SOUTH),
  new Route(47, Direction.NORTH,  Direction.SOUTH),
  new Route(48, Direction.EAST,   Direction.WEST)
  new Route(57, Direction.NORTH,  Direction.SOUTH),
]


module.exports =
  Direction:  Direction
  Route:      Route
  routes:     routes
