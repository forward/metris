express = require 'express'

var Pipe = require('pusher-pipe');
var pipe = Pipe.createClient({key: '27367b8778629ab23d60',
    secret: 'cc826eb2b033de7614c6',
    app_id: 10
});

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