window.pusher = new Pusher(pusher_key)
window.channel = pusher.subscribe(gameID)

window.makeGuid = ->
    S4 = () -> (((1+Math.random())*0x10000)|0).toString(16).substring(1)
    (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4())

window.Tetris =
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
  colors: []
  playerBlockColor:
    h: Math.floor(Math.random()*360)
    s:'60%'
    l:'50%'
  abandonedBlockColor: "#FF0080"
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
  loadAvatar: (callback) ->
    return callback() unless @twitterUsername
    @avatar = "http://api.twitter.com/1/users/profile_image?screen_name=#{@twitterUsername}&size=mini"
    @avatarImage = new Image()
    @avatarImage.onload = => callback(@avatarImage)
    @avatarImage.onerror = =>
      @avatar = @avatarImage = null
      callback(null)
    @avatarImage.src = @avatar
  init: (options) ->
    @twitterUsername = options.twitterUsername
    @loadAvatar => 
      @gs = new JSGameSoup(document.getElementById('tetris'), 25) # framerate
      @am = new AudioManager()
      @am.load '/sounds/block-placed.wav', 'block-placed'
      @am.load '/sounds/line-completed.wav', 'line-completed'
      # random viewport starting position
      @viewportOffset.x = Math.floor(Math.random() * (@levelSize - @viewport.x))
      @height = @viewport.y
      level = new Level()
      @gs.addEntity(level)
      @blocks = new Tetris.AbandonedBlocks()
      @gs.addEntity(@blocks)
      @map = new Map(0, Tetris.viewport.y*Tetris.gridSize+1, @blocks.blocks, @shapes)
      @gs.addEntity(@map)
      channel.trigger 'ready'
      @gs.launch()

class Map
  constructor: (@x, @y, @blocks, @shapes) ->
    @gridSize = 2
  draw: (c) ->
    @drawBlocks(c)
    @drawShapes(c)
    @drawBounds(c)
  drawShapes: (c) ->
    for id, shape of @shapes
      for i in [0,1,2,3]
        block = shape.blockPosition(i)
        @drawBlock(c, block.x, block.y, shape.colorString())
  drawBlocks: (c) ->
    @drawBlock(c, block.x, block.y, Tetris.abandonedBlockColor) for block in @blocks
  drawBlock: (c, x, y, color) ->
    c.fillStyle = color
    x = @x + (@gridSize * x)
    y = @y + (@gridSize * y)
    c.fillRect(x, y, @gridSize, @gridSize)
  drawBounds: (c) ->
    c.strokeStyle = "#bbb"
    start = @x + (Tetris.viewportOffset.x * @gridSize)
    width = Tetris.viewport.x * @gridSize
    height = Tetris.viewport.y * @gridSize
    c.strokeRect(start, @y, width, height)

class Level
  constructor: ->
  draw: (c) ->
    Tetris.gs.clear()
    Tetris.gs.background('rgba(255, 255, 255, 0.3)')
    c.beginPath()
    c.moveTo(0, Tetris.viewport.y*Tetris.gridSize)
    c.lineTo(Tetris.viewport.x*Tetris.gridSize, Tetris.viewport.y*Tetris.gridSize)
    c.strokeStyle = "#bbb"
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
      Tetris.gs.delEntity(block)
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
    c.fillStyle = Tetris.abandonedBlockColor
    c.fillRect(vs.x, vs.y, Tetris.blockSize, Tetris.blockSize)


channel.bind 'created', (data) ->
  return if data.playerID is Tetris.playerID
  shapeClass = Tetris.Shape.types[data.type]
  console.log(data.avatar)
  Tetris.gs.addEntity( new shapeClass(id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color, avatar: data.avatar) )

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
    Tetris.gs.addEntity( new shapeClass(id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color, avatar: data.avatar) )
  for block in info.blocks
    Tetris.blocks.add(new Tetris.Block(x:block.x, y:block.y), false)
  Tetris.gs.addEntity(Tetris.Shape.randomShape(x:Tetris.initialShapeOffset(), y:0, color: Tetris.playerBlockColor, owned: true))

channel.bind 'refreshLines', (blocks) ->
  Tetris.blocks.reset()
  Tetris.am.play 'line-completed'
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

channel.bind 'gameover', ->
  score = $('#score').html()
  $('#wrapper').append('<div id="gameover"><h2>Game Over</h2><p>You scored: <span>'+
                        score +
                        '</span></p><p><a class="tweet" href="https://twitter.com/intent/tweet?via=forwardtek&text=I scored '+
                        score +
                        ' at Metris http://bit.ly/metris #metris #nodeknockout">Tweet it</a> or '+
                        '<a href="/">start over</a></p></div>')

channel.bind 'scoreUpdate', (data) ->
  $('#score').html(data.score)

channel.bind 'players', (data) ->
  if (data.number == 1)
    text = " player online"
  else
    text = " players online"
  $('#playerNumber').html(data.number+text)

channel.bind 'blockAdded', (data) ->
  return if data.playerID is Tetris.playerID
  Tetris.blocks.add(new Tetris.Block(x:data.x, y:data.y), false)

$('.control#left').click ->   Tetris.gs.entitiesCall('keyDown_37')
$('.control#right').click ->  Tetris.gs.entitiesCall('keyDown_39')
$('.control#down').click ->   Tetris.gs.entitiesCall('keyDown_40')
$('.control#rotate').click -> Tetris.gs.entitiesCall('keyDown_38')

gameStart = ->
  $('#score').show()
  $('#playerNumber').show()
  $('#intro').hide()
  username = $('#username-input').val()
  username = null unless username.length > 0
  Tetris.init(twitterUsername: username)
  false

$('a.start-game').click(gameStart)
$('#intro form').submit(gameStart)
