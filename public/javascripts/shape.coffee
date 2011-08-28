class window.Tetris.Shape
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
    @avatar = (if @owned then Tetris.avatar else opts.avatar) || null
    @avatarImage = null
    @loadAvatar()
    Tetris.shapes[@id] = this
    @created() if isNewObj
    
  loadAvatar: ->
    if @owned
      @avatarImage = Tetris.avatarImage
    else
      return unless @avatar
      img = new Image()
      img.onload = (=> @avatarImage = img)
      img.src = @avatar
  
  remove: ->
    Tetris.gs.delEntity(this)
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
  
  colorString: ->
    alpha = if @owned then 1 else 0.4
    if @color.r?
      "rgba(#{@color.r},#{@color.g},#{@color.b},#{alpha})"
    else
      "hsla(#{@color.h},#{@color.s},#{@color.l},#{alpha})"
  
  draw: (c) ->
    drawBlock = (blockDef) =>
      x = @pixelX() + (blockDef[0]*Tetris.gridSize) + 1
      y = @pixelY() + (blockDef[1]*Tetris.gridSize) + 1
      vs = Tetris.viewportSpace(x,y)
      return unless vs.visible
      c.fillStyle = @colorString()
      c.fillRect(vs.x, vs.y, Tetris.blockSize, Tetris.blockSize)
    definition = @shapeDefinition(this.rotation)
    drawBlock(definition[0])
    drawBlock(definition[1])
    drawBlock(definition[2])
    drawBlock(definition[3])
    if @avatarImage
      imgWidth = 48
      v = Tetris.viewportSpace(@pixelX()+(@xShapeOffset()*Tetris.gridSize)+((@pixelWidth()/2) - (imgWidth/2)), @pixelY()-75)
      c.setAlpha(0.5)
      c.drawImage(@avatarImage, v.x, v.y, imgWidth, imgWidth)
  
  width: ->
    maxWidth = 0
    for cords in @shapeDefinition(@rotation)
      maxWidth = cords[0] if cords[0] > maxWidth
    maxWidth - @xShapeOffset() + 1
    
  pixelWidth: ->
    @width() * Tetris.gridSize
    
  height: ->
    maxHeight = 0
    for cords in @shapeDefinition(@rotation)
      maxHeight = cords[1] if cords[1] > maxHeight
    maxHeight - @yShapeOffset() + 1
    
  pixelHeight: ->
    @height() * Tetris.gridSize
  
  xShapeOffset: ->
    min = 4
    for cords in @shapeDefinition(@rotation)
      min = cords[0] if cords[0] < min
    min
    
  yShapeOffset: ->
    min = 4
    for cords in @shapeDefinition(@rotation)
      min = cords[1] if cords[1] < min
    min

  
  pixelX: ->
    @x * Tetris.gridSize
  pixelY: ->
    @y * Tetris.gridSize
  
  drop: ->
    if @canMoveDown()
      @y++
      @moved()
    else
      @shapeInFinalPosition()

  shapeInFinalPosition: ->    
    Tetris.blocks.add(new Tetris.Block(@blockPosition(0)), @owned)
    Tetris.blocks.add(new Tetris.Block(@blockPosition(1)), @owned)
    Tetris.blocks.add(new Tetris.Block(@blockPosition(2)), @owned)
    Tetris.blocks.add(new Tetris.Block(@blockPosition(3)), @owned)
    Tetris.am.play 'block-placed' unless (Tetris.sfxMuted && @owned)
    @remove()
    if @owned
      Tetris.gs.addEntity(Tetris.Shape.randomShape(x:Tetris.initialShapeOffset(), y:0, color: Tetris.playerBlockColor, owned: true))

  created: ->
    channel.trigger 'created',
      playerID: Tetris.playerID,
      x: @x,
      y: @y,
      rotation: @rotation,
      id: @id,
      type: @type,
      color: @color,
      avatar: @avatar

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

  # DOWN
  keyDown_40: ->
    return unless @owned
    return unless @canMoveTo(0,2)
    @y++
    @y++
    @moved()

class window.Tetris.CubeShape extends Tetris.Shape
  type: 'C'
  shapeDefinition: (rotation) ->
    {
      0: [[0,0], [1,1], [0,1], [1,0]],
      1: [[0,0], [1,1], [0,1], [1,0]],
      2: [[0,0], [1,1], [0,1], [1,0]],
      3: [[0,0], [1,1], [0,1], [1,0]]
    }[rotation]

class window.Tetris.LShape extends Tetris.Shape
  type: 'L'
  shapeDefinition: (rotation) ->
    {
      0: [[0,0],[1,0],[1,1],[1,2]],
      1: [[0,1],[1,1],[2,1],[2,0]],
      2: [[0,0],[0,1],[0,2],[1,2]],
      3: [[0,0],[1,0],[2,0],[0,1]]
    }[rotation]

class window.Tetris.JShape extends Tetris.Shape
  type: 'J'
  shapeDefinition: (rotation) ->
    {
      0: [[0,0],[1,0],[0,1],[0,2]],
      1: [[0,0],[1,0],[2,0],[2,1]],
      2: [[1,0],[1,1],[1,2],[0,2]],
      3: [[0,0],[0,1],[1,1],[2,1]]
    }[rotation]

class window.Tetris.SShape extends Tetris.Shape
  type: 'S'
  shapeDefinition: (rotation) ->
    {
      0: [[0,1],[1,1],[1,0],[2,0]],
      1: [[0,0],[0,1],[1,1],[1,2]],
      2: [[0,1],[1,1],[1,0],[2,0]],
      3: [[0,0],[0,1],[1,1],[1,2]]
    }[rotation]

class window.Tetris.ZShape extends Tetris.Shape
  type: 'Z'
  shapeDefinition: (rotation) ->
    {
      0: [[0,0],[1,0],[1,1],[2,1]],
      1: [[1,0],[1,1],[0,1],[0,2]],
      2: [[0,0],[1,0],[1,1],[2,1]],
      3: [[1,0],[1,1],[0,1],[0,2]]
    }[rotation]

class window.Tetris.TShape extends Tetris.Shape
  type: 'T'
  shapeDefinition: (rotation) ->
    {
      0: [[0,0],[1,0],[2,0],[1,1]],
      1: [[0,-1],[0,0],[0,1],[1,0]],
      2: [[0,0],[1,-1],[2,0],[1,0]],
      3: [[2,-1],[1,0],[2,0],[2,1]]
    }[rotation]

class window.Tetris.IShape extends Tetris.Shape
  type: 'I'
  shapeDefinition: (rotation) ->
    {
      0: [[0,0], [0,1], [0,2], [0,3]],
      1: [[-1,1],[0,1],[1,1],[2,1]],
      2: [[0,0], [0,1], [0,2], [0,3]],
      3: [[-1,1],[0,1],[1,1],[2,1]]
    }[rotation]

window.Tetris.Shape.types = {
  'C': Tetris.CubeShape,
  'L': Tetris.LShape,
  'J': Tetris.JShape,
  'S': Tetris.SShape,
  'Z': Tetris.ZShape,
  'T': Tetris.TShape,
  'I': Tetris.IShape
}
