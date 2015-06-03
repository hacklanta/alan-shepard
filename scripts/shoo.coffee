# Description:
#   Hubot shoos people when they speak next.
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#
# Author:
#   @farmdawgnation
#
toShoo = []

module.exports = (robot) ->
  robot.respond /shoo (.+)$/i, (msg) ->
    toShoo.push msg.match[1]
    msg.send "Got it. Will shoo #{msg.match[1]}"

  robot.hear /.*/, (msg) ->
    if toShoo.indexOf(msg.message.user.name) != -1
      msg.send "@#{msg.message.user.name}, http://www.gifsforum.com/images/gif/get%20out/grand/get-out-eccbc87e4b5ce2fe28308fd9f2a7baf3-192.gif"

      toShoo = toShoo.filter (value) ->
        value != msg.message.user.name
