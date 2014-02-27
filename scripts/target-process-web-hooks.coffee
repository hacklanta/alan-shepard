Util = require 'util'
_ = require 'underscore'

TargetProces = require '../lib/target-process'

closeVerbs = ///#{['fix(?:es|ed)?','clos(?:es|ed)?','complet(?:es|ed)?','resolve(?:es|ed)?'].join('|')}///i
updateVerbs = ///#{['update(?:[sd])?','mprove(?:[sd])?','address(?:e[sd])?','re(?:f(?:erence)?(?:s)?)?','see'].join('|')}///i

closedStateByType =
  UserStories:
    Id: 2
    Name: 'Done'
  Tasks:
    Id: 4
    Name: 'Done'
  Bugs:
    Id: 6
    Name: 'Fixed'

entityRegex =
  ///
    ( # entity markers
      \#|
      ticket:|
      issue:|
      item:|
      entity:|
      story:|
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
        if payload.pull_request?.merged_at and payload.action == 'closed'
          # Only close entities if the pull request has been merged and
          # we're closing it.
          [payload.pull_request]
            .concat entitiesForUpdateAndClose(payload.pull_request.body)
        else if payload.pull_request?
          [payload.pull_request, entitiesForUpdate(payload.pull_request.body), []]
        else if payload.comment?
          pullRequestUrl = payload.comment.pull_request_url
          [payload.issue, entitiesForUpdate(payload.comment.body), []]
        else
          [{ number: undefined, title: undefined, html_url: undefined }, [], []]
      
      if issueNumber?
        # For some reason the TP API requires our comment to be in an array.
        updateComment =
          [
            Description:
              """
              <div>
                Referenced from <a href="#{issueUrl}">##{issueNumber}: #{issueTitle}</a>.
              </div>
              """
          ]
        for id in entityIdsToUpdate
          # Always post to UserStories--it doesn't matter, the comment
          # will go through to the appropriate entity anyway.
          targetProcess.post "UserStories/#{id}/Comments", updateComment,
              (result) -> console.log "What? Got dat #{result}"
          # For these, we fire off one POST to each entity type so the right one will take effect.
          for entityType in ['UserStories','Bugs','Tasks']
            targetProcess.post "#{entityType}/#{id}",
              Id: id
              CustomFields: [
                Name: "Pull Request"
                Value:
                  Url: issueUrl
                  Label: "##{issueNumber}: #{issueTitle}"
              ],
              (result) -> console.log "What? Got dat #{result}"

        closeComment =
          [
            Description:
              """
              <div>
                Completed by merging <a href="#{issueUrl}">##{issueNumber}: #{issueTitle}</a>.
              </div>
              """
          ]
        for id in entityIdsToClose
          # Always post to UserStories--it doesn't matter, the comment
          # will go through to the appropriate entity anyway.
          targetProcess.post "UserStories/#{id}/Comments", closeComment
          # For these, we fire off one POST to each entity type so the right one will take effect.
          for entityType in ['UserStories','Bugs','Tasks']
            targetProcess.post "#{entityType}/#{id}",
              Id: id
              EntityState:
                closedStateByType[entityType]
              CustomFields: [
                Name: "Pull Request"
                Value:
                  Url: issueUrl
                  Label: "##{issueNumber}: #{issueTitle}"
              ],
              (result) -> console.log "What? Got dat #{result}"

        res.send 200, "Fired off requests to update #{entityIdsToUpdate} and close #{entityIdsToClose} from PR #{issueNumber}."
      else
        res.send 400, "Expected an issue id but could not find one."

    catch exception
      console.log "It's all gone wrong:", exception, exception.stack
      res.send 500, "It's all gone wrong: #{Util.inspect exception}"
