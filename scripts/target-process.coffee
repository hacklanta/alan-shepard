Util = require 'util'
_ = require 'underscore'

class TargetProcess
  constructor: (@robot) ->

  userInfoForMsg: (msg) ->
    info = @robot.brain.get('target-process')?.userInfoByUserId?[msg.message.user.id] || {}

    unless info.token? && info.userId?
      msg.send """
        Incomplete docking procedure. Try sending me a 'log in to tp as \
        <username> password <password>' message so I can do things on your \
        behalf!
        """

      null
    else
      info

  get: (msg, resource, config, callback) ->
    unless callback?
      callback = config

    {query, headers} = config

    query ||= {}

    unless config.noToken
      {token} = @userInfoForMsg(msg)
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
    authorizationConfig = headers: { Authorization: "Basic #{encodedCredentials}" }, noToken: true

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

  entities =
    'stories': 'UserStories'
    'bugs': 'Bugs'
    'tasks': 'Tasks'

  entityRegex = "(#{Object.keys(entities).join('|')})"

  robot.respond ///show\s+(?:me\s+)?#{entityRegex}$///, (msg) ->
    msg.send "Mission parameters established, launching..."

    userInfo = targetProcess.userInfoForMsg msg

    if userInfo?
      entitySelector = msg.match[1]
      entity = entities[entitySelector]

      targetProcess.get msg, entity, query: { where: "AssignedUser.Id eq #{userInfo.userId}", include: "[Name]" }, (result) ->
        stories = result.Items

        if stories.length
          storyString = stories.map((_) -> " - #{_.Name} (##{_.Id})").join("\n")

          msg.send """
            Here are your #{entitySelector}:
            #{storyString}
          """
        else
          msg.send "You have no #{entitySelector}; aborting launch."

  robot.respond /show (?:me )?stuff/, (msg) ->

  robot.respond /show (me )?backlog$/, (msg) ->
    msg.send "Mission parameters established, launching..."

    userInfo = targetProcess.userInfoForMsg msg
    msg.send "Mock mission completed. Real mission still pending investigation of fuel flow control mechanism."
