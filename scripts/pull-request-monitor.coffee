# Description:
#   Monitor files or directories in GitHub.
#   Notified if a Pull Request is opened, reopened or synchronized
#
# Dependencies:
#   Nope
#
# Configuration:
#   Nope
#
# Commands:
#   hubot monitor {repo} {"dir" or "file"} {path} {humans} - path - a directory or file, humans - who to notify
# 
# Author: 
#   hacklanta


Util = require 'util'

GITHUB_TOKEN = process.env['GITHUB_TOKEN']

module.exports = (robot) ->

  monitorPath = (msg) ->
    repo = msg.match[1].trim()
    type = msg.match[2].trim()
    path = msg.match[3].trim()
    humans = msg.match[4].trim()

    if type == "file"
      pathTo = "files"
    else
      pathTo = "dirs"

    monitorBook = robot.brain.get('monitorBook') || {}
    monitorBook[repo] ||= {}
    monitorBook[repo][pathTo] ||= []

    # QQQ - improvement, see if path exists
    monitorBook[repo][pathTo].push { path: path, humans: humans }
      
    msg.send "monitoring #{type} #{path} in #{repo} for #{humans}"
    msg.send "full monitorBook: #{JSON.stringify(monitorBook)}"

    robot.brain.set 'monitorBook', monitorBook

  robot.respond /monitor (\S+) (dir|file) (\S+) (.+$)/i, (msg) ->
    monitorPath(msg)

  json = {
    "action": "opened",
    "number": 3298,
    "pull_request": {
      "url": "https://api.github.com/repos/elemica/mercury/pulls/3298",
      "id": 22532849,
      "number": 3298,
      "state": "open",
      "locked": false,
      "title": "Expanded Dashboard Rows"
    },
    "head": {
      "repo": {
        "id": 20000106,
        "name": "mercury",
        "full_name": "elemica/mercury"
      }
    }
  }

  robot.router.post '/pull-request-activity', (req, res) ->
    console.log "---------------- POST for pull-request-activity RECEIVED"
    try
      number = req.body.pull_request.number
      action = req.body.action
      repo = req.body.head.repo.name
      
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
                  console.log "--- filename: " + file.filename
                  monitoredFiles = monitorBook[repo].files
                  # monitoredDirectories = monitorBook[repo].dirs
                  for monitoredFile in monitoredFiles
                    if file.filename.match ( monitoredFile.path )
                      console.log("matched file, sending notifications")
                  # for monitoredDirectory in monitoredDirectories
                  #   if file.filename.match ( monitoredDiretory )
                  #     console.log("matched directory, sending notifications")
        else
          console.log "--- ignorable PR"
      else
        console.log "either no data stored or this repo ain't monitored"
        console.log "redis: " + JSON.stringify(robot.brain.get('monitorBook'))

    catch exception
      console.log "It's all gone wrong:", exception, exception.stack
      res.send 500, "It's all gone wrong: #{Util.inspect exception}"
