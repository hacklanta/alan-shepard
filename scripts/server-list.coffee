module.exports = (robot) ->
  robot.respond /show (.*) servers/i, (msg) ->
    awsEnv = msg.match[1]
    exec = require('child_process').exec
    msg.send("Fetching the server list for #{awsEnv}, don't panic this may take a moment:")
    exec "bash /home/jenkins/scripts/jenkins-env-show.sh -E #{awsEnv}", (error, stdout, stderr) ->
      msg.send(stdout)
    