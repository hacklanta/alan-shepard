# Description:
#   Remotely interact with server logs. Batches by largest flowdock message size
#
# Dependencies:
#   Nope
#
# Configuration:
#   Server shell script
#
# Commands:
#   hubot tail {number of lines} from {dev|stg|router-dev|router-stg} {portal|scribe|fabric|rica} - runs tail command on current log from the server and env given
#   hubot grep {search string} from {dev|stg|router-dev|router-stg} {portal|scribe|fabric|rica} - runs grep -i command on current log from the server and env given
# 
# Author: 
#   @riveramj Mike Rivera


module.exports = (robot) ->

  sendLogs = (remainingLogs, msg) ->
      [toSend, rest...] = remainingLogs
      doSend = ->
        msg.send(toSend)
        if (rest.length)
          sendLogs(rest, msg)
      setTimeout doSend, 500

  date = new Date().toISOString().replace(/T.*/, '').replace(/-/g,'_')

  processLogResults = (stdout, msg) ->
    if stdout
      batchedLogs = stdout.match(/(\n|.){1,8000}/g)
      sendLogs(batchedLogs, msg)
    else
      msg.send "Did not find any results"

  robot.respond /tail ([0-9]*) from (dev|router-dev|router-stg|stg) (portal|rica|scribe|fabric)/i, (msg) ->
    tailAmount = msg.match[1]
    env = msg.match[2]
    server = msg.match[3]

    msg.send("Fetching lines from the log. Don't panic this may take a moment:")
 
    exec = require('child_process').exec

    exec "bash /home/jenkins/scripts/jenkins-log-access.sh -C tail -N #{tailAmount} -E #{env} -S #{server}", (err, stdout, stderr)->
      processLogResults(stdout, msg)


  robot.respond /grep "?(.*)"? from (dev|router-dev|router-stg|stg) (portal|rica|scribe|fabric)/i, (msg) ->
    searchValue = msg.match[1]
    env = msg.match[2]
    server = msg.match[3]

    msg.send("Fetching lines from the log. Don't panic this may take a moment:")
 
    exec = require('child_process').exec

    exec "bash /home/jenkins/scripts/jenkins-log-access.sh -C grep -V '#{searchValue}' -E #{env} -S #{server}", (err, stdout, stderr) ->
      processLogResults(stdout, msg)
