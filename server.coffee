express = require 'express'
gameID = 'game1'

pusher_key = (process.env.PUSHER_KEY || 'af77425a09a90cbee51c')

Pipe = require 'pusher-pipe'
pipe = Pipe.createClient
  key:    pusher_key,
  secret: (process.env.PUSHER_SECRET  || 'fb21cbeef5a569dd6b46'),
  app_id: (process.env.PUSHER_APP_ID  || 12)
pipe.connect()
pipe.debug = true

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
    res.render('index', {pipe_key: pusher_key})

port = process.env.PORT || 8080
app.listen port, ->
  console.log "Listening on " + port

shapes = {}
socketShapes = {}

pipe.channel(gameID).on 'event:created', (socketID, data) ->
  shapes[data.id] = {id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color, type: data.type, fixed: true}
  socketShapes[socketID] = data.id
  pipe.channel(gameID).trigger('created', data, socketID)

pipe.channel(gameID).on 'event:moved', (socketID, data) ->
  shapes[data.id].x = data.x
  shapes[data.id].y = data.y
  shapes[data.id].rotation = data.rotation
  pipe.channel(gameID).trigger('moved', data, socketID)

pipe.channel(gameID).on 'event:removed', (socketID, data) ->
  delete shapes[data.id]
  pipe.channel(gameID).trigger('inFinalPosition', data)

pipe.sockets.on 'open', (socketID) ->
  console.log(shapes);
  pipe.socket(socketID).trigger('start', shapes)

pipe.sockets.on 'close', (socketID) ->
  shapeID = socketShapes[socketID]
  delete shapes[shapeID]
  pipe.channel(gameID).trigger('purge', {id:shapeID})

tick = ->
  console.log('tick')
  pipe.channel(gameID).trigger('drop', {})

pipe.on 'connected', ->
  setInterval tick, 500