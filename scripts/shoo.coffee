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
#   hubot shoo {user} - Hubot will send a get out gif the next time someone says something
#
# Author:
#   @farmdawgnation
#
toShoo = []

module.exports = (robot) ->
  robot.respond /shoo (.+)$/i, (msg) ->
    name = msg.match[1].toLowerCase()

    if name.indexOf("@") == 0
      name = name.substring(1, name.length)
    
    toShoo.push name
    msg.send "Got it. Will shoo #{name}"

  robot.hear /.*/, (msg) ->
    if toShoo.indexOf(msg.message.user.name.toLowerCase()) != -1
      msg.send "@#{msg.message.user.name}, http://media.giphy.com/media/FmsOcKwVAFwUo/giphy.gif"

      toShoo = toShoo.filter (value) ->
        value != msg.message.user.name
