Util = require 'util'
_ = require 'underscore'

class TargetProcess
  constructor: (@robot) ->

  userInfoForMsg: (msg) ->
    info = @robot.brain.get('target-process')?.userInfoByUserId?[msg.message.user.id]

    unless info.token? && info.userId?
      msg.send """
        Incomplete docking procedure. Try sending me a 'log me into tp as
        <username> password <password>' message so I can do things on your
        behalf!
        """

      null
    else
      info

  get: (msg, resource, config, callback) ->
    unless callback?
      callback = config

    {query, headers} = config

    {token} = @userInfoForMsg(msg)
    query ||= {}
    query.token = token

    headers ||= {}
    headers['Accept'] ||= 'application/json'

    base =
      _.reduce(
        Object.keys(headers),
        (base, header) -> base.header(header, headers[header]),
        msg.http("https://elemica.tpondemand.com/api/v1/#{resource}")
      )
    
    base
      .query(query)
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

module.exports = (robot) ->
  targetProcess = new TargetProcess(robot)

  robot.respond /log in to tp as ([^ ]+) password ([^ ]+)$/i, (msg) ->
    msg.send "Engaging docking procedure; don't worry, I'll forget your password once I've got an auth token!"

    username = msg.match[1]

    # base64 encode credentials
    encodedCredentials = new Buffer("#{username}:#{msg.match[2]}").toString('base64')
    authorizationConfig = headers: { Authorization: "Basic #{encodedCredentials}" }

    targetProcess.get msg, 'Context', authorizationConfig, (result) ->
      targetProcessUserId = result.LoggedUser.Id

      targetProcess = robot.brain.get('target-process') || {}
      targetProcess.userInfoByUserId ||= {}
      targetProcess.userInfoByUserId[msg.message.user.id] ||= {}
      targetProcess.userInfoByUserId[msg.message.user.id].userId = targetProcessUserId
      robot.brain.set 'target-process', targetProcess

    targetProcess.get msg, 'Authentication', authorizationConfig, (result) ->
      token = result.Token

      targetProcess = robot.brain.get('target-process') || {}
      targetProcess.userInfoByUserId ||= {}
      targetProcess.userInfoByUserId[msg.message.user.id] ||= {}
      targetProcess.userInfoByUserId[msg.message.user.id].token = token
      robot.brain.set 'target-process', targetProcess

  robot.respond /show me stories$/, (msg) ->
    msg.send "Mission parameters established, launching..."

    userInfo = targetProcess.userInfoForMsg(msg)

    if userInfo?
      targetProcess.get msg, 'UserStories', where: "AssignedUser.Id eq #{userInfo.userId}", (result) ->
        stories = result.Items

  robot.respond /show me backlog$/
