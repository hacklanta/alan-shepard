# Description:
#   This monitors if a Pull Request is opened, reopened or closed and
#   notified the user if any files referenced by the PR match the given path.
#
# Dependencies:
#   none
#
# Configuration:
#   GITHUB_TOKEN - sent in Http GET header
#   STEWARD_ORGANIZATION - your GitHub organization or username
#
# Commands:
#   hubot (monitor|monitoring) {repo} for {path} - path is a regex (the script prepends a "/")
#   hubot stop all monitoring period - for everyone, so know what you're doing
#   hubot stop (monitor|monitoring) {repo} for {path}
#   hubot show affairs - for everyone
# 
# Author: 
#   riveramj
#   arigoldx

GITHUB_TOKEN = process.env['GITHUB_TOKEN']
ORGANIZATION = process.env['STEWARD_ORGANIZATION']

module.exports = (robot) ->

  robot.respond /(monitor|monitoring) (\S+) for (\S+$)/i, (msg) ->
    getAffairInOrder(msg)

  getAffairInOrder = (msg) ->
    repo = msg.match[1].trim()
    path = '/' + msg.match[2].trim()

    steward = robot.brain.get('steward') || {}
    steward[repo] ||= []

    steward[repo].push { path: path, user: msg.message.user }
      
    msg.send "Okay. I'm monitoring #{path} in #{repo}."

    robot.brain.set 'steward', steward

  robot.respond /stop (monitor|monitoring) (\S+) for (\S+$)/i, (msg) ->
    stopStewardingAffair(msg)

  stopStewardingAffair = (msg) ->
    user = msg.message.user
    repo = msg.match[1].trim()
    path = '/' + msg.match[2].trim()

    steward = robot.brain.get('steward') || {}
    
    steward[repo] = steward[repo].filter (monitoredPath) ->
      (monitoredPath.path != path) && (monitoredPath.user != user)

    robot.brain.set 'steward', steward

    msg.send "Okay. I'm no longer montioring for #{path} in #{repo} for you."

  robot.respond /stop all monitoring period/i, (msg) ->
    robot.brain.set 'steward', {}

    msg.send "Monitor what? There's nothing to monitor. ;-)"

  robot.respond /show affairs/i, (msg) ->
    steward = robot.brain.get('steward') || {}
    msg.send "steward: #{JSON.stringify(steward)}"

  robot.router.post '/steward/pull-request', (req, res) ->
    try
      payload = JSON.parse req.param('payload')
      action = payload.action
      number = payload.pull_request.number
      repo = payload.repository.name
      
      steward = robot.brain.get('steward')

      if steward && steward[repo]
        if action in ["opened", "reopened", "closed"]
          robot
            .http("https://api.github.com/repos/" + ORGANIZATION + "/" + repo + "/pulls/" + number + "/files")
            .header('Authorization', "token #{GITHUB_TOKEN}")
            .get() (err, res, body) ->
              if err
                robot.send "Encountered an error monitoring PR#{number} :( ${err}"
              else
                files = JSON.parse(body)
                for file in files
                  affairs = steward[repo]
                  for affair in affairs
                    if file.filename.match ( affair.path )
                      envelope = user: affair.user, room: affair.user.room
                      message = "@#{affair.user.name} PR #{number} matched #{affair.path} with" +
                        " #{file.filename} in #{repo}. The PR was #{action}."
                      robot.send envelope, message

    catch exception
      console.log "It's all gone wrong:", exception, exception.stack
