# Description:
#   This monitors if a Pull Request is opened, reopened or synchronized and
#   notified the user if any files referenced by the PR match the given path.
#
# Dependencies:
#   QQQ hmm...
#
# Configuration:
#   QQQ hmm...
#
# Commands:
#   hubot monitor {repo} for {path} - path is a regex (the script prepends a "/")
#   hubot stop all monitoring period - for everyone, so know what you're doing
#   hubot stop monitoring {path} in {repo}
#   hubot show monitorBook - for everyone
# 
# Author: 
#   hacklanta


Util = require 'util'

GITHUB_TOKEN = process.env['GITHUB_TOKEN']

module.exports = (robot) ->

#
#
  robot.respond /monitor (\S+) for (\S+$)/i, (msg) ->
    monitorPath(msg)

  monitorPath = (msg) ->
    repo = msg.match[1].trim()
    # QQQ - need to check that path doesn't already start with a '/'
    path = '/' + msg.match[2].trim()

    monitorBook = robot.brain.get('monitorBook') || {}
    monitorBook[repo] ||= []

    # QQQ - improvement, see if path exists in the brain
    monitorBook[repo].push { path: path, user: msg.message.user }
      
    msg.send "Okay. I'm monitoring #{path} in #{repo}."

    robot.brain.set 'monitorBook', monitorBook

#
#
  robot.respond /stop monitoring (\S+) in (\S+$)/i, (msg) ->
    stopSomeMonitoring(msg)

  stopSomeMonitoring = (msg) ->
    user = msg.message.user
    path = '/' + msg.match[1].trim()
    repo = msg.match[2].trim()

    monitorBook = robot.brain.get('monitorBook') || {}
    
    monitorBook[repo] = monitorBook[repo].filter (monitoredPath) ->
      (monitoredPath.path != path) && (monitoredPath.user != user)

    robot.brain.set 'monitorBook', monitorBook

    msg.send "Okay. I'm no longer montioring for #{path} in #{repo} for you."

#
#
  robot.respond /stop all monitoring period/i, (msg) ->
    robot.brain.set 'monitorBook', {}

    msg.send "Monitor what? There's nothing to monitor. ;-)"

#
#
  robot.respond /show monitorBook/i, (msg) ->
    monitorBook = robot.brain.get('monitorBook') || {}
    msg.send "monitorBook: #{JSON.stringify(monitorBook)}"

#
#
  robot.router.post '/pull-request-activity', (req, res) ->
    console.log "---------------- POST for pull-request-activity RECEIVED"
    try
      number = req.body.pull_request.number
      action = req.body.action
      console.log "     --------- req.body: " + Util.inspect(req.body)
      repo = req.body.repository.name
      
      console.log  "---   number: " + number
      console.log  "---   action: " + action
      console.log  "---     repo: " + repo

      monitorBook = robot.brain.get('monitorBook')

      if monitorBook && monitorBook[repo]
        if action == "opened" || "reopened" || "synchronized"
          console.log "--- found PR to act upon"
          console.log "---   GETting file info"
          robot
            .http("https://api.github.com/repos/elemica/" + repo + "/pulls/" + number + "/files")
            .header('authorization', "token #{GITHUB_TOKEN}")
            .get() (err, res, body) ->
              if err
                robot.send "Encountered and error :( ${err}"
              else
                files = JSON.parse(body)
                length = files.length
                console.log "--- GET files returned " + length + " files"
                for file in files
                  paths = monitorBook[repo]
                  for path in paths
                    if file.filename.match ( path.path )
                      envelope = user: path.user, room: path.user.room
                      message = "@#{path.user.name} PR #{number} matched #{path.path} with #{file.filename} in #{repo}."
                      robot.send envelope, message
        else
          console.log "--- ignorable PR"
      else
        console.log "either no data stored or this repo ain't monitored"
        console.log "redis: " + JSON.stringify(robot.brain.get('monitorBook'))

    catch exception
      console.log "It's all gone wrong:", exception, exception.stack
      res.send 500, "It's all gone wrong: #{Util.inspect exception}"
