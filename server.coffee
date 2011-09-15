express = require 'express'
games = {}
gameIDs = []

pusher_key = process.env.PUSHER_KEY

Pipe = require 'pusher-pipe'
pipe = Pipe.createClient
  key:    pusher_key,
  secret: process.env.PUSHER_SECRET,
  app_id: process.env.PUSHER_APP_ID
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

app.get '/about', (req, res) ->
  res.render('about', {layout: false})


app.get '/game/:id', (req, res) ->
  gameID = req.params.id
  if games[gameID] == undefined
    Grid.load gameID, (theGrid) ->
      games[gameID] =
        shapes: {}
        grid: theGrid
        socketShapes: {}
        intervalId: null
        twitterUsernames: {}
      gameIDs.push(gameID)
      redis.incr('game_count')
      res.render('game', {pipe_key: pusher_key, game: gameID, grid: games[gameID].grid})
  else
    res.render('game', {pipe_key: pusher_key, game: gameID, grid: games[gameID].grid})

app.get '/leaderboard', (req, res) ->
  redis.sort 'scores', 'limit', 0, 100, (err, scores) ->
    res.render('leaderboard', {pipe_key: pusher_key, scores: scores.reverse()})

port = process.env.PORT || 8080
app.listen port, ->
  console.log "Listening on " + port

#######################################################

class Grid
  @load: (gameID, cb) ->
    redis.get gameID, (err, dataString) ->
      grid = new Grid(gameID)
      if dataString
        data = JSON.parse(dataString)
        grid.grid = data.grid
        grid.score = data.score
        grid.ended = data.ended
        console.log("END", data.ended)
      cb(grid)
  
  constructor: (gameID) ->
    @gameID = gameID
    @players = {}
    @score = 0
    @width = 160
    @height = 24
    @grid = []  #pay attention, grid[y][x] !!!
    @ended = false
    for y in [0..@height]
      row = []
      for x in [0..@width]
        row[x] = 0
      @grid[y] = row
  
  save: ->
    redis.set(@gameID, JSON.stringify(grid: @grid, score: @score, ended: @ended))
  
  gameEnded: ->
    @ended = true
    @save()
  
  add: (aBlock) ->
    @grid[aBlock.y][aBlock.x] = 1
    @score += 4 #add four points per block
    @save()

  addPlayer: (socketId, twitterUsername) ->
    @players[socketId] = twitterUsername

  removePlayer: (socketId) ->
    if @players.hasOwnProperty(socketId)
      delete @players[socketId]
      return true
    else
      return false

  numberOfPlayers: ->
    Object.keys(@players).length

  twitterUsers: ->
    users = []
    users.push(username) for socket, username of @players
    users

  blocks: ->
    blocks = []
    for y in [0..@height]
      for x in [0..@width]
        if (@grid[y][x] == 1)
          blocks.push({x: x, y: y})
    blocks

  needsRefresh:  ->
    currentLine = @height
    needsRefresh = false
    newGrid = []
    for y in [0..@height]
      sum = @grid[y].reduce (a, b) -> a + b
      if sum >= @width
        needsRefresh = true
        @grid[0] = @rowOfZeros()
        for line in [y..1]
          @grid[line] = @copyRow(line-1)
    needsRefresh

  copyRow: (number) ->
    line = []
    for x in [0..@width]
      line[x] = @grid[number][x]
    line

  rowOfZeros: ->
    line = []
    for x in [0..@width]
      line[x] = 0
    line

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
  game = games[gameID]
  delete game.shapes[data.id]
  pipe.channel(gameID).trigger('inFinalPosition', data)

pipe.channels.on 'event:blockAdded', (gameID, socketID, data) ->
  game = games[gameID]
  game.grid.add(data)

  pipe.channel(gameID).trigger('blockAdded', data)
  if game.grid.needsRefresh()
    pipe.channel(gameID).trigger('refreshLines', game.grid.blocks())

  pipe.channel(gameID).trigger('scoreUpdate', {score: game.grid.score})
  # console.log('sent score', game.grid.score)

  if (data.y <= 1)  #end of game
    redis.lpush('scores', game.grid.score)
    pipe.channel(gameID).trigger('gameover', {})
    game.grid.gameEnded()
    delete games[gameID]
    gameIDs.splice(gameIDs.indexOf(gameID), 1);

pipe.channels.on 'event:ready', (gameID, socketID, data) ->
  game = games[gameID]
  game.grid.addPlayer(socketID, data.twitterUsername)
  redis.incr('player_count')
  pipe.socket(socketID).trigger('start', shapes:game.shapes, blocks:game.grid.blocks(), score: game.grid.score)
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

  if game.grid.numberOfPlayers() == 0
    if gameIDs.length > 4
      delete games[theGameID]
      gameIDs.splice(gameIDs.indexOf(theGameID), 1);

pipe.on 'connected', ->
  setInterval (->
    for gameID in gameIDs
      pipe.channel(gameID).trigger('drop', {})
  ), 300
