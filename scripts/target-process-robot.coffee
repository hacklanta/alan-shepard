Util = require 'util'
_ = require 'underscore'

TargetProcess = require '../lib/target-process'

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

      targetProcess.updateUserInfoForMsg msg, userId: targetProcessUserId

      if targetProcess.userInfoForMsg(msg, noErrors: true)
        msg.send "Docking successful."

    targetProcess.get msg, 'Authentication', authorizationConfig, (result) ->
      token = result.Token

      targetProcess.updateUserInfoForMsg msg, token: token

      if targetProcess.userInfoForMsg(msg, noErrors: true)
        msg.send "Docking successful."

  entities =
    'stories': 'UserStories'
    'bugs': 'Bugs'
    'tasks': 'Tasks'

  entityRegex = "(#{Object.keys(entities).join('|')})"

  robot.respond ///show\s+(?:me\s+)?#{entityRegex}$///, (msg) ->
    console.log "Mission parameters established for #{entityRegex} lookup, launching..."

    userInfo = targetProcess.userInfoForMsg msg

    if userInfo?
      entitySelector = msg.match[1]
      entity = entities[entitySelector]

      targetProcess.get msg, entity, query: { where: "AssignedUser.Id eq #{userInfo.userId}", include: "[Name]" }, (result) ->
        stories = result.Items

        if stories.length
          storyString = stories.map((_) -> " - #{_.Name} (id:#{_.Id})").join("\n")

          msg.send """
            Here are your #{entitySelector}:
            #{storyString}
          """
        else
          msg.send "You have no #{entitySelector}; aborting launch."

  robot.respond /show (?:me )?stuff/, (msg) ->

  robot.respond /show (me )?backlog$/, (msg) ->
    console.log "Mission parameters established for backlog lookup, launching..."

    userInfo = targetProcess.userInfoForMsg msg
    msg.send "Mock mission completed. Real mission still pending investigation of fuel flow control mechanism."
