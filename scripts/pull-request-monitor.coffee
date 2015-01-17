Util = require 'util'

GITHUB_TOKEN = process.env['GITHUB_TOKEN']

module.exports = (robot) ->

  json = {
    "action": "opened",
    "number": 50,
    "pull_request": {
      "url": "https://api.github.com/repos/baxterthehacker/public-repo/pulls/50",
      "id": 22532849,
      "number": 50,
      "state": "open",
      "locked": false,
      "title": "Update the README with new information",
    },
    "body": "This is a pretty simple change that we need to pull into master.",
    "created_at": "2014-10-10T00:09:50Z",
    "updated_at": "2014-10-10T00:09:50Z",
    "closed_at": null,
    "merged_at": null,
    "merge_commit_sha": "cd3ff078a350901f91f4c4036be74f91d0b0d5d5",
    "assignee": null,
    "milestone": null,
    "commits_url": "https://api.github.com/repos/baxterthehacker/public-repo/pulls/50/commits",
    "review_comments_url": "https://api.github.com/repos/baxterthehacker/public-repo/pulls/50/comments",
    "review_comment_url": "https://api.github.com/repos/baxterthehacker/public-repo/pulls/comments/{number}",
    "comments_url": "https://api.github.com/repos/baxterthehacker/public-repo/issues/50/comments",
    "statuses_url": "https://api.github.com/repos/baxterthehacker/public-repo/statuses/05c588ba8cd510ecbe112d020f215facb17817a6",
    "head": {
      "repo": {
        "id": 20000106,
        "name": "public-repo",
        "full_name": "baxterthehacker/public-repo",
        "owner": {
          "login": "baxterthehacker",
          "id": 6752317,
          "avatar_url": "https://avatars.githubusercontent.com/u/6752317?v=2",
          "gravatar_id": "",
          "url": "https://api.github.com/users/baxterthehacker",
          "html_url": "https://github.com/baxterthehacker",
          "followers_url": "https://api.github.com/users/baxterthehacker/followers",
          "following_url": "https://api.github.com/users/baxterthehacker/following{/other_user}",
          "gists_url": "https://api.github.com/users/baxterthehacker/gists{/gist_id}",
          "starred_url": "https://api.github.com/users/baxterthehacker/starred{/owner}{/repo}",
          "subscriptions_url": "https://api.github.com/users/baxterthehacker/subscriptions",
          "organizations_url": "https://api.github.com/users/baxterthehacker/orgs",
          "repos_url": "https://api.github.com/users/baxterthehacker/repos",
          "events_url": "https://api.github.com/users/baxterthehacker/events{/privacy}",
          "received_events_url": "https://api.github.com/users/baxterthehacker/received_events",
          "type": "User",
          "site_admin": false
        }
      }
    }
  }

  robot.respond /hi/i, (msg) ->
    msg.send json.number
    msg.send json.head.repo.name

  robot.router.post '/pull-request-activity', (req, res) ->
    console.log "---------------- POST for pull-request-activity RECEIVED"

    try
      number = req.body['pull_request']['number']
      action = req.body['action']
      
      console.log  "---   number: " + number
      console.log  "---   action: " + action
      
      if action == "opened" || "reopened" || "synchronized"
        console.log "--- found PR to act upon"
        console.log "---   need to GET file info"
        robot
          .http("https://api.github.com/repos/elemica/mercury/pulls/" + number + "/files")
          .header('authorization', "token #{GITHUB_TOKEN}")
          .get() (err, res, body) ->
            if err
              robot.send "Encountered and error :( ${err}"
            else
              parsedBody = JSON.parse(body)
              parsedRes = JSON.parse(res)
              #length = body.length
              console.log "--- GET files returned " #+ length + " files"
              console.log "--- --- parsedBody: " + parsedBody
              console.log "--- ---  parsedRes: " + parsedRes
              #for file in body
                #console.log "--- --- filename: " + file.filename

      else
        console.log "--- ignorable PR"
      
      # 1 get POST from GH
      # 2 check to see if it's 

      #console.log payload.number + " ============ number"

      #payload = JSON.parse req.param('payload')
      #console.log ">>>>>>>>> payload: " + Util.inspect(payload)

      #robot
      #.http("https://api.github.com/repos/elemica/mercury/pulls/3652/files")
      #.header('authorization', "token #{GITHUB_TOKEN}")
      #.get() (err, res, body) ->
      #if err
      #robot.send "Encountered an erro :( #{err}"
        #else
          #console.log "GET files callback returned"
          #console.log ">>>> res: " + Util.inspect(res)
          #console.log ">>>> body: " + Util.inspect(body)

    catch exception
      console.log "It's all gone wrong:", exception, exception.stack
      res.send 500, "It's all gone wrong: #{Util.inspect exception}"
