Util = require 'util'
_ = require 'underscore'

TargetProcess = require '../lib/target-process'

module.exports = (robot) ->
  targetProcess = new TargetProcess(robot)

  lookupUserInfoByFields = (msg, fields, value, callback) ->
    if fields.length
      targetProcess.get msg, "Users", query: { where: "#{fields.pop()} eq \"#{value}\"" }, (result) ->
        if result.Items?.length
          console.log 'Doin it for', msg.message.user.id, result.Items[0].Id
          targetProcess.updateUserInfoForMsg msg, userId: result.Items[0].Id

          callback? true
        else
          lookupUserInfoByFields msg, fields, value, callback
    else
      callback? false




  robot.respond /I am ([^ ]+) in Target Process\.?$/i, (msg) ->
    loginOrEmail = msg.match[1]

    lookupUserInfoByFields msg, ['Login', 'Email'], loginOrEmail, (succeeded) ->
      if succeeded
        msg.send "Great, I have you as #{loginOrEmail}!"
      else
        msg.send "I couldn't find #{loginOrEmail} in Target Process :( Make sure this is your login or email!"

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
