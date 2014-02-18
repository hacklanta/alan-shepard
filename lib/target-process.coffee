_ = require 'underscore'

class TargetProcess
  constructor: (@robot) ->

  userInfoForMsg: (msg, config) ->
    info = @robot.brain.get('target-process')?.userInfoByUserId?[msg.message.user.id] || {}

    unless info.token? && info.userId?
      unless config?.noErrors? == true
        msg.send """
          Incomplete docking procedure. Try sending me a 'log in to tp as \
          <username> password <password>' message so I can do things on your \
          behalf!
          """

      null
    else
      info

  updateUserInfoForMsg: (msg, updatedFields) ->
    targetProcess = @robot.brain.get('target-process') || {}
    targetProcess.userInfoByUserId ||= {}
    info = (targetProcess.userInfoByUserId[msg.message.user.id] ||= {})

    info[field] = value for field, value of updatedFields

    @robot.brain.set 'target-process', targetProcess

  buildRequest: (resource, headers, query, token) ->
    query ||= {}

    if token?
      query.token = token

    headers ||= {}
    headers['Accept'] ||= 'application/json'

    base =
      _.reduce(
        Object.keys(headers),
        (base, header) -> base.header(header, headers[header]),
        @robot.http("https://elemica.tpondemand.com/api/v1/#{resource}")
      )
    
    base
      .query(query)

  get: (msg, resource, config, callback) ->
    unless callback?
      callback = config

    {query, headers} = config || {}

    token = undefined
    unless config.noToken
      {token} = @userInfoForMsg(msg)

    @buildRequest(resource, headers, query, token)
      .get() (err, res, body) ->
        if err?
          msg.send "It's all gone wrong, aborting mission! Got error: #{err}."
        else if res.statusCode isnt 200
          msg.send "It's all gone wrong, aborting mission! Got #{res.statusCode} response:\n  #{body}"
        else
          try
            result = JSON.parse(body)
            callback?(result)
          catch error
            msg.send """
              It's all gone wrong, aborting mission! That JSON parsing thing didn't work so
              well with:
                #{body}
              got:
                #{Util.inspect(error)}
            """

module.exports = TargetProcess
