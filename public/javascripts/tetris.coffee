pusher = new Pusher(pusher_key)
channel = pusher.subscribe('game1')

makeGuid = ->
    S4 = () -> (((1+Math.random())*0x10000)|0).toString(16).substring(1)
    (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4())

window.startTetris = (gs) ->
  gridSize = 20
  blockSize = gridSize - 2
  shapes = {}
  playerID = makeGuid()

  class Level
    constructor: ->
    draw: () ->
      gs.clear()
      gs.background('rgba(100, 100, 100, 1.0)')

  class Shape
    constructor: (opts={}) ->
      isNewObj = opts.id == undefined
      @id = opts.id || playerID
      @x = opts.x || 0
      @y = opts.y || 0
      @rotation = opts.rotation || 0
      @color = opts.color || '#000'
      @fixed = opts.fixed || false
      shapes[@id] = this
      @created() if isNewObj

    draw: (c) ->
      drawBlock = (blockDef) =>
        x = (@x*gridSize) + (blockDef[0]*gridSize)
        y = (@y*gridSize) + (blockDef[1]*gridSize)
        c.fillStyle = @color
        c.fillRect(x, y, blockSize, blockSize)
      definition = @shapeDefinition(this.rotation)
      drawBlock(definition[0])
      drawBlock(definition[1])
      drawBlock(definition[2])
      drawBlock(definition[3])

    drop: ->
      @y++
      @moved()

    created: ->
      console.log('created sent', @id)
      channel.trigger 'created',
        playerID: playerID,
        x: @x,
        y: @y,
        rotation: @rotation,
        id: @id,
        type: @type,
        color: @color

    moved: ->
      console.log('moved sent', @id)
      channel.trigger 'moved',
        playerID: playerID,
        x: @x,
        y: @y,
        rotation: @rotation,
        id: @id

    # LEFT
    keyDown_37: ->
      return if @fixed
      @x--
      @moved()

    # UP
    keyDown_38: ->
      return if @fixed
      if @rotation is 3
        @rotation = 0
      else
        @rotation += 1
      @moved()

    # RIGHT
    keyDown_39: ->
      return if @fixed
      @x++
      @moved()


  class CubeShape extends Shape
    type: 'C'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0], [1,1], [0,1], [1,0]],
        1: [[0,0], [1,1], [0,1], [1,0]],
        2: [[0,0], [1,1], [0,1], [1,0]],
        3: [[0,0], [1,1], [0,1], [1,0]]
      }[rotation]

  class LShape extends Shape
    type: 'L'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0],[1,0],[1,1],[1,2]],
        1: [[0,1],[1,1],[2,1],[2,0]],
        2: [[0,0],[0,1],[0,2],[1,2]],
        3: [[0,0],[1,0],[2,0],[0,1]]
      }[rotation]

  class JShape extends Shape
    type: 'J'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0],[1,0],[0,1],[0,2]],
        1: [[0,0],[1,0],[2,0],[2,1]],
        2: [[1,0],[1,1],[1,2],[0,2]],
        3: [[0,0],[0,1],[1,1],[2,1]]
      }[rotation]

  class SShape extends Shape
    type: 'S'
    shapeDefinition: (rotation) ->
      {
        0: [[0,1],[1,1],[1,0],[2,0]],
        1: [[0,0],[0,1],[1,1],[1,2]],
        2: [[0,1],[1,1],[1,0],[2,0]],
        3: [[0,0],[0,1],[1,1],[1,2]]
      }[rotation]

  class ZShape extends Shape
    type: 'Z'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0],[1,0],[1,1],[2,1]],
        1: [[1,0],[1,1],[0,1],[0,2]],
        2: [[0,0],[1,0],[1,1],[2,1]],
        3: [[1,0],[1,1],[0,1],[0,2]]
      }[rotation]

  class TShape extends Shape
    type: 'T'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0],[1,0],[2,0],[1,1]],
        1: [[0,-1],[0,0],[0,1],[1,0]],
        2: [[0,0],[1,-1],[2,0],[1,0]],
        3: [[2,-1],[1,0],[2,0],[2,1]]
      }[rotation]

  class IShape extends Shape
    type: 'I'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0], [0,1], [0,2], [0,3]],
        1: [[-1,1],[0,1],[1,1],[2,1]],
        2: [[0,0], [0,1], [0,2], [0,3]],
        3: [[-1,1],[0,1],[1,1],[2,1]]
      }[rotation]

  Shape.types = {
    'C': CubeShape,
    'L': LShape,
    'J': JShape,
    'S': SShape,
    'Z': ZShape,
    'T': TShape,
    'I': IShape
  }

  channel.bind 'created', (data) ->
    console.log('created got', data.id)
    shapeClass = Shape.types[data.type]
    if playerID != data.id
      gs.addEntity( new shapeClass(id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color, fixed: true) )

  channel.bind 'moved', (data) ->
    console.log('moved got', data.id)
    shape = shapes[data.id]
    return unless shape?
    shape.x = data.x
    shape.y = data.y
    shape.rotation = data.rotation

  pusher.back_channel.bind 'start', (s) ->
    console.log(s)
    for id, data of s
      console.log('start got', id, data)
      shapeClass = Shape.types[data.type]
      gs.addEntity( new shapeClass(id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color, fixed: true) )

  channel.bind 'purge', (data) ->
    shape = shapes[data.id]
    gs.delEntity(shape)
    delete shapes[data.id]

  channel.bind 'drop', ->
    for id, data of shapes
      console.log('dropping', id)
      shapes[id].drop()

  level = new Level()
  gs.addEntity(level)
  pusher.connection.bind 'connected', ->
    # gs.addEntity(new ZShape(x:1, y:1, color: '#f00', fixed: true))
    # gs.addEntity(new SShape(x:5, y:5, color: '#0f0', fixed: false))
    # gs.addEntity(new CubeShape(x:2, y:7, color: '#00f', fixed: false))
    gs.addEntity(new LShape(x:1, y:2, color: '#ff0', fixed: false))
