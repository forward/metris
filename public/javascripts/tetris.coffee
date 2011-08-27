pusher = new Pusher(pusher_key)
channel = pusher.subscribe('game1')

makeGuid = ->
    S4 = () -> (((1+Math.random())*0x10000)|0).toString(16).substring(1)
    (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4())

window.startTetris = (gs) ->
  
  Tetris =
    gridSize: 20
    blockSize: 18
    viewport: # blocks
      x: 16
      y: 24
    initialShapeOffset: -> 
      @viewportOffset.x + (@viewport.x/2) - 2
    levelSize: 160 # blocks
    viewportOffset: # blocks
      x: 0
      y: 0
    shapes: {}
    playerID: makeGuid()
    viewportSpace: (x,y) ->
      ret = {x: x-(@viewportOffset.x*@gridSize), y: y-(@viewportOffset.y*@gridSize)}
      ret.visible = ret.x >= 0 && ret.x <= (@viewport.x*@gridSize)
      ret
    maybeAdjustViewport: (shape) ->
      leftDiff = shape.x - @viewportOffset.x
      if leftDiff <= 2 and @viewportOffset.x > 0
        @viewportOffset.x -= 1
      rightDiff = (@viewportOffset.x+@viewport.x) - (shape.x+4)
      if rightDiff <= 2 and (@viewportOffset.x+@viewport.x) < @levelSize
        @viewportOffset.x += 1
    init: ->
      @height = @viewport.y
      level = new Level()
      gs.addEntity(level)
      @blocks = new Tetris.AbandonedBlocks()
      gs.addEntity(@blocks)
      @map = new Map(0, Tetris.viewport.y*Tetris.gridSize+1, @blocks.blocks, @shapes)
      gs.addEntity(@map)
      pusher.connection.bind 'connected', ->
        gs.addEntity(Tetris.Shape.randomShape(x:Tetris.initialShapeOffset(), y:0, color: {r:0, g:0, b:0}, owned: true))
  
  class Map
    constructor: (@x, @y, @blocks, @shapes) ->
      @gridSize = 2
    draw: (c) ->
      @drawBlocks(c)
      @drawShapes(c)
      @drawBounds(c)
    drawShapes: (c) ->
      null
    drawBlocks: (c) ->
      c.fillStyle = "#00b"
      for block in @blocks
        x = @x + (@gridSize * block.x)
        y = @y + (@gridSize * block.y)
        c.fillRect(x, y, @gridSize, @gridSize)
    drawBounds: (c) ->
      c.strokeStyle = "#0f0"
      start = @x + (Tetris.viewportOffset.x * @gridSize)
      end = start + (Tetris.viewport.x * @gridSize)
      height = Tetris.viewport.y * @gridSize
      c.strokeRect(start, @y, end, height)
    
  class Level
    constructor: ->
    draw: (c) ->
      gs.clear()
      gs.background('rgba(200, 200, 200, 1.0)')
      c.beginPath()
      c.moveTo(0, Tetris.viewport.y*Tetris.gridSize)
      c.lineTo(Tetris.viewport.x*Tetris.gridSize, Tetris.viewport.y*Tetris.gridSize)
      c.strokeStyle = "#0f0"
      c.stroke()
      
  class Tetris.AbandonedBlocks
    constructor: ->
      @blocks = []
    
    add: (block, notify=true) ->
      @blocks.push(block) 
      if notify
        channel.trigger 'blockAdded', x: block.x, y: block.y, playerID: Tetris.playerID
        
    reset: ->
      for block in @blocks
        gs.delEntity(block)
      @blocks = []
      
    draw: (c) -> 
      block.draw(c) for block in @blocks
      
    contains: (x,y) ->
      for block in @blocks
        if block.x == x && block.y == y
          return true 
      return false
      
  class Tetris.Block
    constructor: (opts={})->
      @x = opts.x
      @y = opts.y    
    
    draw: (c) ->
      vs = Tetris.viewportSpace(@x*Tetris.gridSize+1, @y*Tetris.gridSize+1)
      return unless vs.visible
      c.fillStyle = "#c00"
      c.fillRect(vs.x, vs.y, Tetris.blockSize, Tetris.blockSize)
          
      
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
      
    blockPosition: (blockNumber, rotation=null) ->
       definition = @shapeDefinition(rotation || @rotation)[blockNumber]
       x = @x + definition[0] 
       y = @y + definition[1]
       {x: x, y: y}
    
    canMoveDown: ->
      return @canMoveTo(0, +1)
      
    canMoveTo: (xOffset, yOffset, rotation=null) ->
      for i in [0,1,2,3]
        x = @blockPosition(i, rotation).x + xOffset
        y = @blockPosition(i, rotation).y + yOffset
        return false if Tetris.blocks.contains(x, y)
        return false if x < 0
        return false if x >= Tetris.levelSize
        return false if y >= Tetris.viewport.y
      return true
    
    draw: (c) ->
      rgba = (o, alpha=1) ->
        "rgba(#{o.r},#{o.g},#{o.b},#{alpha})"
      drawBlock = (blockDef) =>
        x = (@x*Tetris.gridSize) + (blockDef[0]*Tetris.gridSize) + 1 
        y = (@y*Tetris.gridSize) + (blockDef[1]*Tetris.gridSize) + 1
        alpha = if @owned then 1 else 0.4
        vs = Tetris.viewportSpace(x,y)
        return unless vs.visible
        c.fillStyle = rgba(@color, alpha)
        c.fillRect(vs.x, vs.y, Tetris.blockSize, Tetris.blockSize)
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
      Tetris.blocks.add(new Tetris.Block(@blockPosition(0)))
      Tetris.blocks.add(new Tetris.Block(@blockPosition(1)))
      Tetris.blocks.add(new Tetris.Block(@blockPosition(2)))
      Tetris.blocks.add(new Tetris.Block(@blockPosition(3)))
      @remove()
      if @owned
        gs.addEntity(Tetris.Shape.randomShape(x:Tetris.initialShapeOffset(), y:0, color: {r:0, g:0, b:0}, owned: true))      

    created: ->
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
      Tetris.maybeAdjustViewport(this)
      channel.trigger 'moved',
        playerID: Tetris.playerID,
        x: @x,
        y: @y,
        rotation: @rotation,
        id: @id

    # LEFT
    keyDown_37: ->
      return unless @owned
      return unless @canMoveTo(-1, 0)
      @x--
      @moved()

    # UP
    keyDown_38: ->
      return unless @owned
      if @rotation is 3
        newRotation = 0
      else
        newRotation = @rotation + 1
      if @canMoveTo(0,0,newRotation)
        @rotation = newRotation
        @moved()

    # RIGHT
    keyDown_39: ->
      return unless @owned
      return unless @canMoveTo(1, 0)
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
    return if data.playerID is Tetris.playerID
    shapeClass = Tetris.Shape.types[data.type]
    gs.addEntity( new shapeClass(id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color) )

  channel.bind 'moved', (data) ->
    return if data.playerID is Tetris.playerID
    shape = Tetris.shapes[data.id]
    return unless shape?
    shape.x = data.x
    shape.y = data.y
    shape.rotation = data.rotation

  pusher.back_channel.bind 'start', (info) ->
    for id, data of info.shapes
      shapeClass = Tetris.Shape.types[data.type]
      gs.addEntity( new shapeClass(id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color) )
    for block in info.blocks
      Tetris.blocks.add(new Tetris.Block(x:block.x, y:block.y), false)
      
  channel.bind 'refreshLines', (blocks) ->
    Tetris.blocks.reset()
    for block in blocks
      Tetris.blocks.add(new Tetris.Block(x:block.x, y:block.y), false)
      
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
      Tetris.shapes[id].drop()
      
  channel.bind 'endOfGame', ->
    console.log("THE END!")
  
  channel.bind 'blockAdded', (data) ->
    return if data.playerID is Tetris.playerID
    Tetris.blocks.add(new Tetris.Block(x:data.x, y:data.y), false)

  Tetris.init()
