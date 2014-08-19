
module.exports = (robot) ->
  robot.respond /show (.*) servers/i, (msg) ->
    awsEnv = msg.match[1]
    exec = require('child_process').exec
    switch awsEnv
      when "dev", "stg", "prd", "router-dublin-dev", "router-oregon-stg", "router-integration-stg"
        exec "bash /home/jenkins/scripts/jenkins-env-show.sh -E #{awsEnv}", (error, stdout, stderr) ->
          msg.send(stdout)
      else
        msg.reply "Sorry! You didn't enter a valid aws environment, try again."