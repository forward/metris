pusher = new Pusher(pusher_key)
channel = pusher.subscribe('game1')

makeGuid = ->
    S4 = () -> (((1+Math.random())*0x10000)|0).toString(16).substring(1)
    (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4())

window.startTetris = (gs) ->
  
  Tetris =
    gridSize: 20
    blockSize: 18
    viewport: 
      x: 320
      y: 480
    shapes: {}
    playerID: makeGuid()
    init: ->
      @height = @viewport.y / @gridSize
      level = new Level()
      gs.addEntity(level)
      @blocks = new Tetris.AbandonedBlocks()
      gs.addEntity(@blocks)
      pusher.connection.bind 'connected', ->
        gs.addEntity(Tetris.Shape.randomShape(x:0, y:0, color: {r:0, g:0, b:0}, owned: true))
  class Level
    constructor: ->
    draw: () ->
      gs.clear()
      gs.background('rgba(200, 200, 200, 1.0)')
      
  class Tetris.AbandonedBlocks
    constructor: ->
      @blocks = []
    
    add: (block) ->
      @blocks.push(block)    
      
    draw: (c) -> 
      block.draw(c) for block in @blocks
      
  class Tetris.Block
    constructor: (opts={})->
      @x = opts.x
      @y = opts.y    
      console.log("BLOCK", @x, @y)
    
    draw: (c) ->
      c.fillStyle = "#000"
      c.fillRect(@x*Tetris.gridSize+1, @y*Tetris.gridSize+1,Tetris.blockSize, Tetris.blockSize)  
          
      
  class Tetris.Shape
    @randomShape: (opts) ->
      keys = Object.keys(Tetris.Shape.types)
      pos = Math.floor(Math.random()*keys.length)
      new Tetris.Shape.types[keys[pos]](opts)
    constructor: (opts={}) ->
      isNewObj = opts.id == undefined
      @id = opts.id || makeGuid()
      @x = opts.x || 0
      @y = opts.y || 0
      @rotation = opts.rotation || 0
      @color = opts.color || {r:0, g:0, b:0, a:1}
      @owned = opts.owned || false
      Tetris.shapes[@id] = this
      @created() if isNewObj
      
    remove: ->
      gs.delEntity(this)
      delete Tetris.shapes[@id]
      if @owned
        channel.trigger 'removed', 
          id: @id,
          playerID: Tetris.playerID,
          x: @x,
          y: @y,
          rotation: @rotation
      
        
    blockPosition: (blockNumber) ->
       definition = @shapeDefinition(this.rotation)[blockNumber]
       x = @x + definition[0] 
       y = @y + definition[1]
       {x: x, y: y}
    
    canMoveDown: ->
      test = Tetris.height - 1
      for i in [0,1,2,3]
        return false if @blockPosition(i).y == test
      return true
    
    draw: (c) ->
      rgba = (o, alpha=1) ->
        "rgba(#{o.r},#{o.g},#{o.b},#{alpha})"
      drawBlock = (blockDef) =>
        x = (@x*Tetris.gridSize) + (blockDef[0]*Tetris.gridSize) + 1 
        y = (@y*Tetris.gridSize) + (blockDef[1]*Tetris.gridSize) + 1
        alpha = if @owned then 1 else 0.4
        c.fillStyle = rgba(@color, alpha)
        c.fillRect(x, y, Tetris.blockSize, Tetris.blockSize)
      definition = @shapeDefinition(this.rotation)
      drawBlock(definition[0])
      drawBlock(definition[1])
      drawBlock(definition[2])
      drawBlock(definition[3])

    drop: ->
	    if @canMoveDown()
        @y++
        @moved()
      else
        @shapeInFinalPosition()
        
    shapeInFinalPosition: ->
      console.log("final position!!!!!!!!!!!!!!!!!!!")
      Tetris.blocks.add(new Tetris.Block(@blockPosition(0)))
      Tetris.blocks.add(new Tetris.Block(@blockPosition(1)))
      Tetris.blocks.add(new Tetris.Block(@blockPosition(2)))
      Tetris.blocks.add(new Tetris.Block(@blockPosition(3)))
      @remove()
      if @owned
        gs.addEntity(Tetris.Shape.randomShape(x:0, y:0, color: {r:0, g:0, b:0}, owned: true))      

    created: ->
      console.log('created sent', @id)
      channel.trigger 'created',
        playerID: Tetris.playerID,
        x: @x,
        y: @y,
        rotation: @rotation,
        id: @id,
        type: @type,
        color: @color

    moved: ->
      return unless @owned
      console.log('moved sent', @id)
      channel.trigger 'moved',
        playerID: Tetris.playerID,
        x: @x,
        y: @y,
        rotation: @rotation,
        id: @id

    # LEFT
    keyDown_37: ->
      return unless @owned
      @x--
      @moved()

    # UP
    keyDown_38: ->
      return unless @owned
      if @rotation is 3
        @rotation = 0
      else
        @rotation += 1
      @moved()

    # RIGHT
    keyDown_39: ->
      return unless @owned
      @x++
      @moved()


  class Tetris.CubeShape extends Tetris.Shape
    type: 'C'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0], [1,1], [0,1], [1,0]],
        1: [[0,0], [1,1], [0,1], [1,0]],
        2: [[0,0], [1,1], [0,1], [1,0]],
        3: [[0,0], [1,1], [0,1], [1,0]]
      }[rotation]

  class Tetris.LShape extends Tetris.Shape
    type: 'L'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0],[1,0],[1,1],[1,2]],
        1: [[0,1],[1,1],[2,1],[2,0]],
        2: [[0,0],[0,1],[0,2],[1,2]],
        3: [[0,0],[1,0],[2,0],[0,1]]
      }[rotation]

  class Tetris.JShape extends Tetris.Shape
    type: 'J'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0],[1,0],[0,1],[0,2]],
        1: [[0,0],[1,0],[2,0],[2,1]],
        2: [[1,0],[1,1],[1,2],[0,2]],
        3: [[0,0],[0,1],[1,1],[2,1]]
      }[rotation]

  class Tetris.SShape extends Tetris.Shape
    type: 'S'
    shapeDefinition: (rotation) ->
      {
        0: [[0,1],[1,1],[1,0],[2,0]],
        1: [[0,0],[0,1],[1,1],[1,2]],
        2: [[0,1],[1,1],[1,0],[2,0]],
        3: [[0,0],[0,1],[1,1],[1,2]]
      }[rotation]

  class Tetris.ZShape extends Tetris.Shape
    type: 'Z'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0],[1,0],[1,1],[2,1]],
        1: [[1,0],[1,1],[0,1],[0,2]],
        2: [[0,0],[1,0],[1,1],[2,1]],
        3: [[1,0],[1,1],[0,1],[0,2]]
      }[rotation]

  class Tetris.TShape extends Tetris.Shape
    type: 'T'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0],[1,0],[2,0],[1,1]],
        1: [[0,-1],[0,0],[0,1],[1,0]],
        2: [[0,0],[1,-1],[2,0],[1,0]],
        3: [[2,-1],[1,0],[2,0],[2,1]]
      }[rotation]

  class Tetris.IShape extends Tetris.Shape
    type: 'I'
    shapeDefinition: (rotation) ->
      {
        0: [[0,0], [0,1], [0,2], [0,3]],
        1: [[-1,1],[0,1],[1,1],[2,1]],
        2: [[0,0], [0,1], [0,2], [0,3]],
        3: [[-1,1],[0,1],[1,1],[2,1]]
      }[rotation]

  Tetris.Shape.types = {
    'C': Tetris.CubeShape,
    'L': Tetris.LShape,
    'J': Tetris.JShape,
    'S': Tetris.SShape,
    'Z': Tetris.ZShape,
    'T': Tetris.TShape,
    'I': Tetris.IShape
  }

  channel.bind 'created', (data) ->
    console.log('created got', data.id)
    return if data.playerID is Tetris.playerID
    shapeClass = Tetris.Shape.types[data.type]
    gs.addEntity( new shapeClass(id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color) )

  channel.bind 'moved', (data) ->
    console.log('moved got', data.id)
    return if data.playerID is Tetris.playerID
    shape = Tetris.shapes[data.id]
    return unless shape?
    shape.x = data.x
    shape.y = data.y
    shape.rotation = data.rotation

  pusher.back_channel.bind 'start', (s) ->
    for id, data of s
      console.log('start got', id, data)
      shapeClass = Tetris.Shape.types[data.type]
      gs.addEntity( new shapeClass(id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color) )

  channel.bind 'purge', (data) ->
    shape = Tetris.shapes[data.id]
    shape.remove()
  
  channel.bind 'inFinalPosition', (data) ->
    return if data.playerID is Tetris.playerID
    shape = Tetris.shapes[data.id]
    shape.x = data.x
    shape.y = data.y
    shape.rotation = data.rotation
    shape.shapeInFinalPosition()

  channel.bind 'drop', ->
    for id, data of Tetris.shapes
      console.log('dropping', id)
      Tetris.shapes[id].drop()

  Tetris.init()
