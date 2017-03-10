
# ================================================
# Client-side entrace to the app
# This has a lot of dependency imports which are
# passed around as arguments to the other files.
# ================================================

# This is a bit unintuitive, but the following require automatically
# attaches the CSS stylesheet to the DOM.
require("./style/app.sass")

# Deps from NPM
import Vue from 'vue'
import Vuex from 'vuex'
mapState = Vuex.mapState
$ = require 'jquery'
import VueRouter from 'vue-router'
Cookies = require('cookies-js')
deps = { Vue, $, Vuex, mapState, VueRouter, Cookies }

# Custom deps which need to be added in order
Object.assign deps,
  Store: require('./lib/store').load { deps }
Object.assign deps,
  components: require('./components/components').load { deps }
Object.assign deps,
  Router: require('./lib/router').load { deps } 

# Define app class
class Client

  constructor: ({deps}) ->
    { Cookies, components, Router } = deps
    Object.assign this,
      { Cookies, components, Router }
      # To set the data of a component, it needs to be instantiated
      #
      # If there are multiple versions of a component on the page,
      # updating the instance's $data will change all of them.
      #
      # For that use-case, the child components' props should be bound its
      # parent and the parent updated (to reduce side effecs)
      # 
      # There probably are ways to get refs to specific children
      # of a parent - see the Vue docs on that.
    Object.assign this,
      auth: new(@components.authenticator)().$data

  anchor: $("#vue-anchor")[0]

  load: ->
    @root = @components.root.activate({ Router: @Router })
    @root.$mount @anchor
    @get_token().then @init_websockets
    window.components = @components

  get_token: ->
    new Promise (resolve, reject) =>
      token = @token_from_cookie()
      if token
        resolve({token})
      else
        @new_credentials_or_token_from_server(resolve)

  token_from_cookie: ->
    @Cookies.get "token"

  new_credentials_or_token_from_server: (callback) ->
     $.get "http://localhost:3000/token", (response) ->
      { token } = JSON.parse response
      callback({ token })

  init_websockets: ({token}) =>
    @Cookies.set("token", token)
    @current_token = token
    @ws = new WebSocket "ws://localhost:3000/ws?token=#{token}"
    @ws.onopen = =>
      @auth.token = @current_token
      @try_authenticate(token: @current_token)
    @ws.onmessage= (message) =>
      data = JSON.parse(message.data)
      if data.action == 'logged_in'
        @set_authenticated_state { username: data.username }
      else if data.msg
        console.log data.msg
    @ws.onclose = (x,y) => (setTimeout =>
      @init_websockets({token})
    , 1000)

  # The response will be sent as a "logged_in" action
  try_authenticate: ({token}) ->
    @ws.send JSON.stringify
      action: "try_authenticate"
      token: token

  set_authenticated_state: ({username}) =>
    @auth.done = true
    @auth.username = username

  # TODO logout

# Start app
$ -> new Client({deps}).load()



