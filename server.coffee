express = require 'express'
games = {}
gameIDs = []

require('nko')('LqNOy7Hy1JHYB4yU')

pusher_key = (process.env.PUSHER_KEY || 'af77425a09a90cbee51c')

Pipe = require 'pusher-pipe'
pipe = Pipe.createClient
  key:    pusher_key,
  secret: (process.env.PUSHER_SECRET  || 'fb21cbeef5a569dd6b46'),
  app_id: (process.env.PUSHER_APP_ID  || 12)
pipe.connect()
# pipe.debug = true

if process.env.REDISTOGO_URL
  rtg   = require("url").parse(process.env.REDISTOGO_URL);
  redis = require("redis").createClient(rtg.port, rtg.hostname);

  redis.auth(rtg.auth.split(":")[1]);
else
  redis = require("redis").createClient()

makeGuid = ->
    S4 = () -> (((1+Math.random())*0x10000)|0).toString(16).substring(1)
    (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4())

app = express.createServer express.logger()

app.configure ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.bodyParser()
  app.use express.methodOverride()
  publicDir = __dirname + '/public'
  app.use express.compiler({ src: publicDir, enable: ['less', 'coffeescript'] })
  app.use app.router
  app.use express.static(publicDir)

app.get '/', (req, res) ->
  newGame = makeGuid()
  redis.get 'player_count', (err, playerCount) ->
    redis.get 'game_count', (err, gameCount) ->
      res.render('index', {pipe_key: pusher_key, games: games, newGame: newGame, gameCount: gameCount, playerCount: playerCount})

app.get '/game/:id', (req, res) ->
  gameID = req.params.id
  if games[gameID] == undefined
    games[gameID] = {
      shapes: {},
      grid: new Grid(160,24),
      socketShapes: {},
      intervalId: null
    }
    gameIDs.push(gameID)
    redis.incr('game_count')
  res.render('game', {pipe_key: pusher_key, game: gameID})

port = process.env.PORT || 8080
app.listen port, ->
  console.log "Listening on " + port

#######################################################

class Grid

  constructor: (x,y) ->
    @players = []
    @score = 0
    @width = x
    @height = y
    @grid = []  #pay attention, grid[y][x] !!!
    for y in [0..@height]
      row = []
      for x in [0..@width]
        row[x] = 0

      @grid[y] = row

  add: (aBlock) ->
    # console.log('adding a block', aBlock.y, aBlock.x)
    @grid[aBlock.y][aBlock.x] = 1
    @score += 4 #add four points per block

  addPlayer: (socketId) ->
    @players.push(socketId)

  removePlayer: (socketId) ->
    if (@players.indexOf(socketId) > -1)
      @players.splice(@players.indexOf(socketId), 1)
      return true
    else
      return false

  numberOfPlayers: ->
    @players.length

  blocks: ->
    blocks = []
    for y in [0..@height]
      for x in [0..@width]
        if (@grid[y][x] == 1)
          blocks.push({x: x, y: y})
    blocks


  needsRefresh:  ->
    needsRefresh = false
    MAX_LINE_LENGTH = 16
    for y in [0..@height]
      lineOpen = false
      counter = 0
      for x in [0..@width]
        elem = @grid[y][x]
        if !lineOpen
          counter = 0
        if elem == 1 && lineOpen
          counter++
        if elem == 1 && !lineOpen
          lineOpen = true
          counter++
          # console.log("counter", counter)          
        if elem == 0 && lineOpen 
          lineOpen = false          
          # console.log("closed with counter", counter)                    
          
        if (counter >= MAX_LINE_LENGTH && ( !lineOpen || x >= @width))
          # console.log("start shift")
          baseline = y
          from = x - counter 
          to = x
          console.log('shifting', baseline, from, to)          
          for xx in [from..to]
            @grid[0][xx] = 0
          for yy in [baseline..1]
            for xx in [from..to]
              @grid[yy][xx] = @grid[yy-1][xx] 
          
          console.log("shifted")
          needsRefresh = true
          @score += (4*counter)
              
    needsRefresh
  

pipe.channels.on 'event:created', (gameID, socketID, data) ->
  game = games[gameID]
  game.shapes[data.id] = {id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color, type: data.type, avatar: data.avatar, fixed: true}
  game.socketShapes[socketID] = data.id

  pipe.channel(gameID).trigger('created', data, socketID)

pipe.channels.on 'event:moved', (gameID, socketID, data) ->
  game = games[gameID]
  game.shapes[data.id].x = data.x
  game.shapes[data.id].y = data.y
  game.shapes[data.id].rotation = data.rotation
  pipe.channel(gameID).trigger('moved', data, socketID)

pipe.channels.on 'event:removed', (gameID, socketID, data) ->
  delete game.shapes[data.id]
  pipe.channel(gameID).trigger('inFinalPosition', data)

pipe.channels.on 'event:blockAdded', (gameID, socketID, data) ->
  game = games[gameID]
  game.grid.add(data)

  pipe.channel(gameID).trigger('blockAdded', data)
  
  pipe.channel(gameID).trigger('scoreUpdate', {score: game.grid.score})
  # console.log('sent score', game.grid.score)

  if (data.y <= 1)  #end of game
    pipe.channel(gameID).trigger('gameover', {})
    delete games[gameID]
    gameIDs.splice(gameIDs.indexOf(gameID), 1);
    
pipe.channels.on 'event:recalculate', (gameID, socketID, data) ->    
  console.log("RECALCULATION!!!!", gameID)  
  game = games[gameID]  
  if game.grid.needsRefresh()
    pipe.channel(gameID).trigger('refreshLines', game.grid.blocks())
    pipe.channel(gameID).trigger('scoreUpdate', {score: game.grid.score})  

pipe.channels.on 'event:ready', (gameID, socketID, data) ->
  game = games[gameID]
  game.grid.addPlayer(socketID)
  redis.incr('player_count')
  pipe.socket(socketID).trigger('start', shapes:game.shapes, blocks:game.grid.blocks())
  pipe.channel(gameID).trigger('players', {number: game.grid.numberOfPlayers()})

pipe.sockets.on 'close', (socketID) ->
  theGameID = null
  for gameID in gameIDs
    if games[gameID].grid.removePlayer(socketID)
      theGameID = gameID

  game = games[theGameID]
  pipe.channel(theGameID).trigger('players', {number: game.grid.numberOfPlayers()})

  shapeID = game.socketShapes[socketID]
  delete game.shapes[shapeID]
  pipe.channel(theGameID).trigger('purge', {id:shapeID})

pipe.on 'connected', ->
  setInterval (->
    for gameID in gameIDs
      pipe.channel(gameID).trigger('drop', {})
  ), 300
