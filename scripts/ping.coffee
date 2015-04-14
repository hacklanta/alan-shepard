# Description:
#   Hubot responds when he hears his name
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
#   @riveramj
#
phrases = [
  "Ready to blast off!"
  "At your service"
  "I'm here. As always"
  "Ready to work!"
  "Yes?"
  "More work?"
  "Ready for orders"
  "Orders?"
  "What do you need?"
  "Say the word"
  "Locked and loaded"
  "Aye?"
  "I await your orders"
  "Ready for a new mission"
  "Here"
  "What ails you?"
  "Yes, my friend?"
  "Is my aid required?"
  "Do you need help?"
  "It's hammer time!"
  "You're interrupting my calculations!"
  "You rang?"
  "At your call"
  "You require my assistance?"
  "What is it now?"
  "Hmm?"
  "I'm ready and waiting"
  "Ah, at last"
  "I'm here"
  "Something need doing?"
]

randomPhrase = -> phrases[Math.floor(Math.random() * phrases.length)]

module.exports = (robot) ->
  robot.hear ///(?:.+)\s+#{robot.name}(?:.*)///i, (msg) ->
    msg.send randomPhrase ->

  robot.respond /ping/i, (msg) ->
    msg.send randomPhrase ->

  robot.respond /[\?|\!|\.]+/i, (msg) ->
    msg.send randomPhrase ->
