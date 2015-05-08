bootstrap = require 'bootstrap-browserify'

Backbone = require 'backbone4000'
helpers = require 'helpers'
bitcoinhelpers = require 'bitcoinhelpers'

_ = window._ =  require 'underscore'
$ = require 'jquery-browserify'
async = require 'async'

lweb = require 'lweb3/transports/client/engineio'
queryProtocol = require 'lweb3/protocols/query'
channelProtocol = require 'lweb3/protocols/channel'
collectionProtocol = require 'lweb3/protocols/collection'

window.noty = noty = require 'noty-browserify'

common = require './clientside/common'

models = require './clientside/models'
collections = require 'collections'
views = require './clientside/views'

#
# quickplay should send a current gamelist filter validator as a request
# and server would directly use it as a filter for the database
#

settings =
    #websockethost: window.location.protocol + "://" + window.location.host
    websockethost: "ws://" + window.location.host
    simulatedelay: true

    ping:
        freq: 5000
        statsSubmit: true
        statsSubmitAfter: 5

env = {}

window.env = env
env.settings = settings

setInitStatus = (str) -> $('#initstatus').html(str)

initRoutes = (env,callback) ->
    routes =
        "_=_": -> env.router.navigate '/', trigger: true
        "login": -> true
        "logout": -> -> true
#        "game/:id": (id) ->
#            env.mainView.navigate views.game, (callback) -> true

    routerClass = Backbone.Router.extend routes: routes
    env.router = new routerClass()
    Backbone.history.start pushState: true
    callback()

initLogger = (env,callback) ->
    env.log = (text,data,taglist...) ->
        tags = {}
        _.map taglist, (tag) -> tags[tag] = true
        if tags.error then text = text.red
        if tags.error and _.keys(data).length then json = " " + JSON.stringify(msg.data) else json = ""
        console.log "-> " + _.keys(tags).join(', ') + " " + text + json

    env.wrapInit = (text, f) ->
        (callback) ->
            console.log '>', text

            f env, ((err,data) ->
                    console.log '<', text, "DONE"
                    callback err,data
                )

    env.log('logger', {}, 'init', 'ok')

    callback()

gatherInfo = (env,callback) ->
    env.hostdata = {}
    if navigator.doNotTrack then callback(); return
    crawl = (object,attributes) -> helpers.dictMap attributes, (value,attr) -> object[attr]
    env.hostdata.browser = crawl navigator, ['appCodeName', 'appVersion', 'userAgent', 'vendor']
    env.hostdata.screen = crawl window.screen, ['height','width','colorDepth']
    env.hostdata.os = platform: navigator.platform, language: navigator.language
    callback()

initCore = (env,callback) ->
    env.lweb = new lweb.engineIoClient( host: env.settings.websockethost, verbose: false )
    env.lweb.addProtocol new queryProtocol.client( verbose: true )
    env.lweb.addProtocol new channelProtocol.client( verbose: false )
    env.lweb.addProtocol new collectionProtocol.client
        verbose: false
        collectionClass: collections.ModelMixin.extend4000 collections.ReferenceMixin, collectionProtocol.clientCollection
    callback()

initWebsocket = (env,callback) ->
    #if env.lweb.attributes.socketIo.connected then callback()
    env.lweb.on 'connect', ->
        helpers.wait 100, ->
            console.log 'connect!'
            callback()

loadCookies = (env,callback) ->
    env.cookies = {}
    _.map document.cookie.split(';'), (cookie) ->
        key = helpers.trim(cookie.substr(0, cookie.indexOf("=")))
        value = cookie.substr cookie.indexOf("=") + 1
        if key and value then env.cookies[key] = value
    if _.keys(env.cookies).length then callback null, 'Yes' else callback null, 'Not Found'

initCollections = (env,callback) ->
    env.games = env.lweb.collection 'games'
    env.tournaments = env.lweb.collection 'tournaments'
    env.users = env.lweb.collection 'users', autosubscribe: false
    env.chats = env.lweb.collection 'chats'
    env.replays = env.lweb.collection 'replays'
    env.spawners = env.lweb.collection 'spawners'
    env.transactions = env.lweb.collection 'transactions'
    env.serviceCollection = env.lweb.collection 'service'
    callback()

initModels = (env,callback) -> models.init env,callback

initPreUserViews = exports.initPreUserViews = (env,callback) ->
    views.init env, ->
        env.main = new Backbone.Model visible: true
        env.mainView = new views.main el: $('body'), model: env.main
        env.mainView.render()
        callback()

login = (env,callback) ->
    doLogin = (secret,callback) ->
        if secret then env.lweb.query { cookieSecret: secret }, (msg) ->
            callback msg.err, msg.user

    newUser = (callback) ->
        query = newuser: true

        if window.location.hash.length > 2 then query.parent = window.location.hash.substring(1)

        env.lweb.query query, (msg) ->
            if not msg.err then noty.noty { text: "Created New User (#{ msg.user.name })", timeout: 2000, closewith: 'hover', type: 'information' }
            else noty.noty { text: msg.err, type: 'error' }
            callback msg.err, msg.user

    gotUser = (err,user) ->
        window.location.hash = ''
        if err then return callback err
#        window.location.hash = user.secret

        env.main.set self: env.self = new env.model.self(user)
        document.cookie = "secret=" + user.cookieSecret + ";max-age=" + 60 * 60 * 24 * 30 * 12
        env.headerView = new views.header model: env.self, el: $('#header')
        env.headerView.render()
        env.headerView.$el.slideDown()

        env.lweb.subscribe userupdate: true, (msg) ->
            console.log "REMOTECHANGERECEIVE",msg
            env.self.remoteChangeReceive action: 'update', update: msg.userupdate

        callback()

    cookieLogin = (callback) ->
        if secret = env.cookies.secret then doLogin secret, callback
        else callback()

    failDialog = ->
        dialog = new views.loginFailDialog
            model: new Backbone.Model()
            callback: ->
                newUser gotUser
        dialog.render()

    helloDialog = (callback) ->
        dialog = new views.helloDialog
            model: new Backbone.Model()
            callbackNew: -> newUser gotUser
            callbackLogin: gotUser

        env.mainView.openTab dialog

     cookieLogin (err,user) ->
        if err and err.code isnt 1
            noty.noty { text: err, type: 'error' }
            return failDialog()
        if not user then helloDialog gotUser
        else gotUser null, user

waitDocument = (env,callback) -> $(document).ready -> callback()


init = (env,callback) ->
    initLogger env, ->
        async.auto
            documentready: ((callback) -> waitDocument env, callback)
            views:       [ 'documentready', (callback) -> initPreUserViews env, callback ]
            core:        [ 'views', env.wrapInit "Initializing core...", initCore ]
            info:        [ 'views', env.wrapInit "Gathering host information...", gatherInfo ]
            cookies:     [ 'views', env.wrapInit "Checking cookies...", loadCookies ]
            websocket:   [ 'core', env.wrapInit "Initializing connection...", initWebsocket ]
            collections: [ 'core', env.wrapInit "Initializing database...", initCollections ]
            models:      [ 'core', 'collections', env.wrapInit "Initializing models...", initModels ]
            login:       [ 'views', 'websocket', 'models', env.wrapInit "Logging in...", login ]
            callback


init env, (err,data) ->
    if err then env.log('clientside init failed', {}, 'init', 'fail', 'error');return
    env.log('clientside ready', {}, 'init', 'ok', 'completed')
    #env.MainView.tab('lobby')
