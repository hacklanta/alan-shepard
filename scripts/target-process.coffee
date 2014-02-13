Util = require 'util'

module.exports = (robot) ->
  robot.respond /log me into tp as ([^ ]+) password ([^ ]+)$/i, (msg) ->
    msg.send "Engaging docking procedure; don't worry, I'll forget your password once I've got an auth token!"

    username = msg.match[1]

    # base64 encode credentials
    encodedCredentials = new Buffer("#{username}:#{msg.match[2]}").toString('base64')
    
    msg.http("https://elemica.tpondemand.com/api/v1/Authentication")
      .header('Accept', 'application/json')
      .header('Authorization', "Basic #{encodedCredentials}")
      .get() (err, res, body) ->
        if err?
          msg.send "It's all gone wrong, aborting dock procedure! Got error: #{err}."
        else if res.statusCode isnt 200
          msg.send "It's all gone wrong, aborting dock procedure! Got #{res.statusCode} response:\n  #{body}"
        else
          try
            token = JSON.parse(body).Token

            tp = robot.brain.get('target-process') || {}
            tp.tokensByUserId ||= {}
            tp.tokensByUserId[msg.message.user.id] = token
            robot.brain.set 'target-process', tp

            msg.send "Successfully docked with TargetProcess as #{username}. Get processing!"
          catch error
            msg.send "It's all gone wrong, aborting dock procedure! That JSON parsing thing didn't work so well with:\n#{body}...; got:\n#{Util.inspect(error)}"
