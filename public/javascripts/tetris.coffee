window.startTetris = (gs) ->
  gridSize = 20;
  blockSize = gridSize - 2;
  
  class Level
    constructor: ->
    draw: () ->
      gs.clear()
      gs.background('rgba(100, 100, 100, 1.0)')
  
  class Shape
    constructor: (opts) ->
      @x = opts.x || 0
      @y = opts.y || 0
      @rotation = opts.rotation || 0
      @color = opts.color || '#000'

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
    
    # LEFT
    keyDown_37: ->
      @x--
    
    # UP
    keyDown_38: ->
      if @rotation is 3
        @rotation = 0
      else 
        @rotation += 1
    
    # RIGHT
    keyDown_39: ->
      @x++  
  
  
  class CubeShape extends Shape
    shapeDefinition: (rotation) ->
      { 
        0: [[0,0], [1,1], [0,1], [1,0]], 
        1: [[0,0], [1,1], [0,1], [1,0]], 
        2: [[0,0], [1,1], [0,1], [1,0]], 
        3: [[0,0], [1,1], [0,1], [1,0]] 
      }[rotation]
    
  class LShape extends Shape
    shapeDefinition: (rotation) ->
      { 
        0: [[0,0],[1,0],[1,1],[1,2]], 
        1: [[0,1],[1,1],[2,1],[2,0]], 
        2: [[0,0],[0,1],[0,2],[1,2]], 
        3: [[0,0],[1,0],[2,0],[0,1]]
      }[rotation]
    
  class JShape extends Shape
    shapeDefinition: (rotation) ->
      { 
        0: [[0,0],[1,0],[0,1],[0,2]], 
        1: [[0,0],[1,0],[2,0],[2,1]], 
        2: [[1,0],[1,1],[1,2],[0,2]], 
        3: [[0,0],[0,1],[1,1],[2,1]]
      }[rotation]
    
  class SShape extends Shape
    shapeDefinition: (rotation) ->
      { 
        0: [[0,1],[1,1],[1,0],[2,0]], 
        1: [[0,0],[0,1],[1,1],[1,2]], 
        2: [[0,1],[1,1],[1,0],[2,0]], 
        3: [[0,0],[0,1],[1,1],[1,2]]
      }[rotation]
    
  class ZShape extends Shape
    shapeDefinition: (rotation) ->
      { 
        0: [[0,0],[1,0],[1,1],[2,1]], 
        1: [[1,0],[1,1],[0,1],[0,2]], 
        2: [[0,0],[1,0],[1,1],[2,1]], 
        3: [[1,0],[1,1],[0,1],[0,2]]
      }[rotation]
    
  class TShape extends Shape
    shapeDefinition: (rotation) ->
      { 
        0: [[0,0],[1,0],[2,0],[1,1]], 
        1: [[0,-1],[0,0],[0,1],[1,0]], 
        2: [[0,0],[1,-1],[2,0],[1,0]], 
        3: [[2,-1],[1,0],[2,0],[2,1]]
      }[rotation]
    
  class IShape extends Shape
    shapeDefinition: (rotation) ->
      { 
        0: [[0,0], [0,1], [0,2], [0,3]], 
        1: [[-1,1],[0,1],[1,1],[2,1]], 
        2: [[0,0], [0,1], [0,2], [0,3]], 
        3: [[-1,1],[0,1],[1,1],[2,1]]
      }[rotation]
  
    
  level = new Level()
  gs.addEntity(level)
  gs.addEntity(new ZShape(x:1, y:1, color: '#f00'))
  gs.addEntity(new SShape(x:5, y:5, color: '#0f0'))
  gs.addEntity(new CubeShape(x:2, y:7, color: '#00f'))
  gs.addEntity(new TShape(x:8, y:3, color: '#000'))
