# Description:
#   Retrieve lines from a server log. Batches by largest flowdock message size
#
# Dependencies:
#   Nope
#
# Configuration:
#   Server shell script
#
# Commands:
#   hubot tail {number of lines} from {dev|stg|router-dev|router-stg} {portal|scribe|fabric|rica} - runs tail command on log from the server and env given
# 
# Author: 
#   @riveramj Mike Rivera


module.exports = (robot) ->

  sendLogs = (remainingLogs, msg) ->
      [toSend, rest...] = remainingLogs
      doSend = ->
        msg.send(toSend)
        if (rest.length)
          sendLogs(rest)
      setTimeout doSend, 500

  date = new Date().toISOString().replace(/T.*/, '').replace(/-/g,'_')

  robot.respond /tail ([0-9]*) from (dev|router-dev|router-stg|stg) (portal|rica|scribe|fabric)/i, (msg) ->
    tailAmount = msg.match[1]
    env = msg.match[2]
    server = msg.match[3]

    msg.send("Fetching lines from the log. Don't panic this may take a moment:")
 
    exec = require('child_process').exec

    exec "bash /home/jenkins/scripts/jenkins-tail-logs.sh -N #{tailAmount} -E #{env} -S #{server}", (err, stdout, stderr)->

      batchedLogs = stdout.match(/(\n|.){1,8000}/g)

      sendLogs(batchedLogs, msg)
