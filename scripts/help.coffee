# Description:
#   Generates help commands for Hubot.
#
# Commands:
#   hubot help - Displays all of the help commands that Hubot knows about.
#   hubot help <query> - Displays all help commands that match <query>.
#
# URLS:
#   /hubot/help
#
# Notes:
#   These commands are grabbed from comment blocks at the top of each file.

helpSummary = [
  'Type help <keyword> for specific help or "hubot full help" for entire list ',
  '',
  'Events',
  'Haters - Returns a random haters gonna hate url',
  'Jenkins - Show Jobs. Show current branch for job. Change branch and build',
  'Good List/Bad List - Show, add, remove from lists',
  'Github - search github repo',
  'Domain - Is domain up?'
  'JoinMe - create join.me link/room',
  'Generate Hash - Generate hash of string',
  'Pomodoro - Start, stop, show details',
  'Rabbit - Show nodes, queues, bindings, vhosts, etc',
  'Tell - Tell someone something when they login next',
  'Encode/Decode Url - URL encode or decode',
  'Ship it - Ship it squirrel!'
]

helpContents = (name, commands) ->

  """
<html>
  <head>
  <title>#{name} Help</title>
  <style type="text/css">
    body {
      background: #d3d6d9;
      color: #636c75;
      text-shadow: 0 1px 1px rgba(255, 255, 255, .5);
      font-family: Helvetica, Arial, sans-serif;
    }
    h1 {
      margin: 8px 0;
      padding: 0;
    }
    .commands {
      font-size: 13px;
    }
    p {
      border-bottom: 1px solid #eee;
      margin: 6px 0 0 0;
      padding-bottom: 5px;
    }
    p:last-child {
      border: 0;
    }
  </style>
  </head>
  <body>
    <h1>#{name} Help</h1>
    <div class="commands">
      #{commands}
    </div>
  </body>
</html>
  """

module.exports = (robot) ->
  SendHelp = (typeOfhelp, msg) ->
    prefix = robot.alias or robot.name
    cmds = typeOfhelp.map (cmd) ->
      cmd = cmd.replace /^hubot/, prefix
      cmd.replace /hubot/ig, robot.name

    emit = cmds.join "\n"

    msg.send emit

  robot.respond /help\s*(.*)?$/i, (msg) ->
    cmds = robot.helpCommands()
    filter = msg.match[1]

    if filter
      cmds = cmds.filter (cmd) ->
        cmd.match new RegExp(filter, 'i')
      if cmds.length == 0
        msg.send "No available commands match #{filter}"
        return
    
    SendHelp helpSummary, msg
    
  robot.respond /full help$/i, (msg) ->
    cmds = robot.helpCommands()
    SendHelp cmds, msg

  robot.router.get "/#{robot.name}/help", (req, res) ->
    cmds = robot.helpCommands().map (cmd) ->
      cmd.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')

    emit = "<p>#{cmds.join '</p><p>'}</p>"

    emit = emit.replace /hubot/ig, "<b>#{robot.name}</b>"

    res.setHeader 'content-type', 'text/html'
    res.end helpContents robot.name, emit
