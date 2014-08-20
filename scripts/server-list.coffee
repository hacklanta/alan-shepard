
module.exports = (robot) ->
  robot.respond /show (.*) servers/i, (msg) ->
    awsEnv = msg.match[1]
    exec = require('child_process').exec
    switch awsEnv
      when "dev", "stg", "prd", "if-team-dev", "router-dublin-dev", "router-oregon-stg", "router-integration-stg"
        msg.send("Fetching the server list for #{awsEnv}, don't panic this may take a moment:")
        exec "bash /home/jenkins/scripts/jenkins-env-show.sh -E #{awsEnv}", (error, stdout, stderr) ->
          msg.send(stdout)
      else
        msg.reply "Sorry! You didn't enter a valid Mercury environment, try again."