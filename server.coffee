express = require 'express'

Pipe = require 'pusher-pipe'
pipe = Pipe.createClient
  key: '27367b8778629ab23d60',
  secret: 'cc826eb2b033de7614c6',
  app_id: 10
pipe.connect()

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
    res.render('index', {})

port = process.env.PORT || 8080
app.listen port, ->
  console.log "Listening on " + port

pipe.channels.on 'event', (eventName, channelName, socket_id, data) ->
  console.log('eventName '+ eventName)
  console.log('channelName '+ channelName)
  console.log('socket_id '+ socket_id)
  console.log(data)

shapes = {}

pipe.channel('game1').on 'event:created', (socketID, data) ->
  shapes[data.id] = {id: data.id, x:data.x, y:data.y, rotation: data.rotation, color: data.color, fixed: true}
  pipe.channel('game1').trigger('created', data)

pipe.channel('game1').on 'event:moved', (socketID, data) ->
  shapes[data.id].x = data.x
  shapes[data.id].y = data.y
  shapes[data.id].rotation = data.rotation
  pipe.channel('game1').trigger('moved', data)

pipe.sockets.on 'open', (socket_id) ->
  pipe.channel('game1').trigger('start', shapes)

# when a new person connects ->
  # send current state