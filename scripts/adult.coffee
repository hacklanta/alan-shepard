module.exports = (robot) ->
  robot.hear /(I|we) need an adult/i, (msg) ->
    msg.send "@Sloan"
