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
#   hubot grep [-A #, -B #, -C #] {search string} from {dev|stg|router-dev|router-stg} {portal|scribe|fabric|rica} - runs grep -i command on current log from the server and env given. Before, After and Context flags are supported.
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

  robot.respond /tail ([0-9]*) from ([A-z\-]*) ([A-z\-]*)/i, (msg) ->
    validServers = /portal|rica|scribe|fabric/i
    validEnvironments = /dev|router-dev|router-stg|stg/i

    tailAmount = msg.match[1]
    env = msg.match[2]
    server = msg.match[3]
 
    if !env.match validEnvironments
      msg.send """
        Bad environment #{env}
        Valid environments are: portal|rica|scribe|fabric
        """
    else if !server.match validServers
      msg.send """
        Bad server: #{server}
        Valid servers are: dev|router-dev|router-stg|stg
        """
    else
      msg.send "Fetching lines from the log. Don't panic this may take a moment:"
  
      exec = require('child_process').exec
  
      exec "bash /home/jenkins/scripts/jenkins-log-access.sh -C tail -N #{tailAmount} -E #{env} -S #{server}", (err, stdout, stderr)->
        processLogResults(stdout, msg)

  robot.respond /grep ((?:-(?:[ABC]?) (?:[0-9]+)\s*)*)\s*"?(.*)"? from (dev|router-dev|router-stg|stg) (portal|rica|scribe|fabric)/i, (msg) ->
    rawFlags = msg.match[1]
    flags = rawFlags.split('-').splice(1)

    after = ''
    before = ''
    context = ''

    extractNumberOfLines = (flag) ->
      flag.replace(/\D+/g, '')

    for flag in flags
      switch flag.charAt(0).toLowerCase()
        when "a" then after = extractNumberOfLines flag
        when "b" then before = extractNumberOfLines flag
        when "c" then context = extractNumberOfLines flag
        else msg.send "no match for flag'" + flag + "'"

    searchValue = msg.match[2]
    env = msg.match[3]
    server = msg.match[4]

    msg.send("Fetching lines from the log. Don't panic this may take a moment:")
 
    exec = require('child_process').exec

    exec "bash /home/jenkins/scripts/jenkins-log-access.sh -C grep -A '#{after}' -B '#{before}' -X '#{context}' -V '#{searchValue}' -E #{env} -S #{server}", (err, stdout, stderr) ->
      processLogResults(stdout, msg)
