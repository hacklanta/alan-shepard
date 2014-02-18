Util = require 'util'
_ = require 'underscore'

TargetProces = require '../lib/target-process'

closeVerbs = ///#{['fix(?:es|ed)?','clos(?:es|ed)?','complet(?:es|ed)?','resolve(?:es|ed)?'].join('|')}///i
updateVerbs = ///#{['update(?:[sd])?','mprove(?:[sd])?','address(?:e[sd])?','re(?:f(?:erence)?(?:s)?)?','see'].join('|')}///i

entityRegex =
  ///
    ( # entity markers
      \#|
      ticket:|
      issue:|
      item:|
      entity:|
      bug:
    )
    (\d+) # entity id
  ///ig

updateRegex =
  ///
    ( # change verbs
      #{closeVerbs.source}|
      #{updateVerbs.source}
    )
    \s+ # at least one space
    (?: # 1+ entities
      #{entityRegex.source}
      (?:,\s*(?:and\s)?|\sand\s)? # combined either by ","; ", and"; or just "and"
    )+
  ///ig

# Finds both closing and updating references and adds a comment to the
# associated TargetProcess entities indicating what just happened.
entitiesForUpdate = (string) ->
  _.flatten(
    while match = updateRegex.exec(string)
      while entityMatch = entityRegex.exec(match[0])
        entityMatch[2] 
  )

# Finds both closing and updating references and adds a comment to the
# associated TargetProcess entities indicating what just happened.
# Additionally, if the reference was a closing reference, moves the
# TargetProcess entity to a "Fixed" state (for bugs) or a "Done" state
# (for user stories and tasks).
entitiesForUpdateAndClose = (string) ->
  [entityIdsToUpdate, entityIdsToClose] = [[], []]

  while match = updateRegex.exec(string)
    collection =
      if match[1].match updateVerbs
        entityIdsToUpdate
      else if match[1].match closeVerbs
        entityIdsToClose

    while entityMatch = entityRegex.exec(match[0])
      collection.push entityMatch[2]

  [entityIdsToUpdate, entityIdsToClose]

module.exports = (robot) ->
  targetProcess = new TargetProces(robot)

  robot.router.post '/target-process/pull-request', (req, res) ->
    try
      payload = JSON.parse req.param('payload')

      [{number: issueNumber, title: issueTitle, html_url: issueUrl},
       entityIdsToUpdate, entityIdsToClose] =
        if payload.pull_request?.merged_at and payload.action? == 'closed'
          console.log 'tryin it right'
          # Only close entities if the pull request has been merged and
          # we're closing it.
          [payload.pull_request]
            .concat entitiesForUpdateAndClose(payload.pull_request.body)
        else if payload.pull_request?
          console.log 'tryin it well'
          [payload.pull_request, entitiesForUpdate(payload.pull_request.body), []]
        else if payload.comment?
          [payload.issue, entitiesForUpdate(payload.comment.body), []]
        else
          [undefined, [], []]

      # For some reason the TP API requires our comment to be in an array.
      comment =
        [
          Description:
            """
            <div>
              Referenced from <a href="#{issueUrl}">##{issueNumber} #{issueTitle}</a>.
            </div>
            """
        ]

      for id in entityIdsToUpdate
        # Always post to UserStories--it doesn't matter, the comment
        # will go through to the appropriate entity anyway.
        targetProcess.post "UserStories/#{id}/Comments", comment

    catch exception
      console.log "It's all gone wrong:", exception, exception.stack
      res.send 500, "It's all gone wrong: #{Util.inspect exception}"
