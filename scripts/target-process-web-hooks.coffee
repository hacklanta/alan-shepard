Util = require 'util'
_ = require 'underscore'
_.str = require('underscore.string');

TargetProces = require '../lib/target-process'

TARGET_PROCESS_HOST = process.env['TARGET_PROCESS_HOST']
GITHUB_TOKEN = process.env['GITHUB_TOKEN']

closeVerbs = ///#{['fix(?:e[sd])?','close[sd]?','complete[sd]?','resolve[sd]?','implement(?:s|ed)?'].join('|')}///i
updateVerbs = ///#{['update[sd]?','improve[sd]?','address(?:e[sd])?','re(?:f(?:erence)?(?:s)?)?','see'].join('|')}///i

inProgressStateByType =
  UserStories:
    Id: 67
    Name: 'In Progress'
  Tasks:
    Id: 69
    Name: 'In Progress'
  Bugs:
    Id: 70
    Name: 'In Progress'

closedStateByType =
  UserStories:
    Id: 2
    Name: 'Done'
  Tasks:
    Id: 4
    Name: 'Done'
  Bugs:
    Id: 8
    Name: 'Closed'

entityRegex =
  ///
    \[? # present if this mention has already been hyperlinked in Github
    ( # entity markers
      \#|
      ticket:|
      issue:|
      item:|
      entity:|
      story:|
      bug:|
      task:
    )
    (\d+) # entity id
    \]? # present if this mention has already been hyperlinked in Github
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
      (?:\([^)]+\))? # present if this mention has already been hyperlinked in Github
      (?:,\s*(?:and\s)?|\sand\s)? # combined either by ","; ", and"; or just "and"
    )+
  ///ig

# Finds both closing and updating references and adds a comment to the
# associated TargetProcess entities indicating what just happened.
entitiesForUpdate = (string) ->
  _.flatten(
    while match = updateRegex.exec(string)
      while entityMatch = entityRegex.exec(match[0]) when ! _.str.endsWith(entityMatch[0], ']')
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
    # Note: below, close entities are always reported, while update
    # entities are only reported if they haven't been linked in
    # Github (since we only want to update an entity once if it's just
    # mentioned).
    if match[1].match updateVerbs
      while entityMatch = entityRegex.exec(match[0]) when ! _.str.endsWith(entityMatch[0], ']')
        entityIdsToUpdate.push entityMatch[2]
    else if match[1].match closeVerbs
      while entityMatch = entityRegex.exec(match[0])
        entityIdsToClose.push entityMatch[2]


  [entityIdsToUpdate, entityIdsToClose]

# Updates the specified body with links to the specified ids if they are
# referenced anywhere without already being linked.
updateBodyWithEntityLinks = (body, entityIdsToLink) ->
  console.log 'replacing in', body, 'with', entityIdsToLink
  body.replace updateRegex, (updateString, updateVerb, entityMarker, entityId) ->
    updateString.replace entityRegex, (entityMention, entityMarker, entityId) ->
      if entityIdsToLink.indexOf(entityId) > -1 && ! _.str.endsWith(entityMention, ']')
        "[#{entityMention}](#{TARGET_PROCESS_HOST}/entity/#{entityId})"
      else
        entityMention


# Given a pull request body, id, and list of entity ids, update the pull
# request body to link references to those entity ids to their entries in
# Target Process.
addLinksToPullRequest = (pullRequestUrl, pullRequestBody) -> (robot, pullRequestId, entityIds) ->
  updatedBody = updateBodyWithEntityLinks pullRequestBody, entityIds

  console.log 'putting', updatedBody, 'to', pullRequestId
  # put to Github the updated body
  robot
    .http(pullRequestUrl)
    .header('Authorization', "token #{GITHUB_TOKEN}")
    .header('Accept', 'application/json')
    .patch(JSON.stringify(
      body: updatedBody
    )) (err, res, body) ->
      if err?
        console.log "It's all gone wrong... Got: #{res}"

addLinksToComment = (commentUrl, commentId, commentBody) -> (robot, pullRequestId, entityIds) ->
  updatedBody = updateBodyWithEntityLinks commentBody, entityIds

  console.log 'putting', updatedBody, 'to', commentId
  # put to Github the updated body
  robot
    .http(commentUrl)
    .header('authorization', "token #{github_token}")
    .header('Accept', 'application/json')
    .patch(JSON.stringify(
      body: updatedBody
    )) (err, res, body) ->
      if err?
        console.log "It's all gone wrong... Got: #{res}"

module.exports = (robot) ->
  targetProcess = new TargetProces(robot)

  robot.router.post '/pull-request-activity', (req, res) ->
    console.log "BOOM SHAKALAKAH"
    robot
      .http("https://api.github.com/repos/elemica/mercury/pulls/3652/files")
      .header('authorization', "token #{github_token}")
      .get() (err, res, body) ->
        if err
          robot.send "Encountered an erro :( #{err}"
        else
          console.log("VERY VERY VERY BOOM SHAKALAKAH")

  robot.router.post '/target-process/pull-request', (req, res) ->
    try
      payload = JSON.parse req.param('payload')

      [{number: issueNumber, title: issueTitle, html_url: issueUrl},
       linkAdderFn, entityIdsToUpdate, entityIdsToClose] =
        if payload.pull_request?.merged_at and payload.action == 'closed'
          # Only close entities if the pull request has been merged and
          # we're closing it.
          [payload.pull_request, addLinksToPullRequest(payload.pull_request.url, payload.pull_request.body)]
            .concat entitiesForUpdateAndClose(payload.pull_request.body)
        else if payload.pull_request?
          [payload.pull_request, addLinksToPullRequest(payload.pull_request.url, payload.pull_request.body),
            entitiesForUpdate(payload.pull_request.body), []]
        else if payload.comment?
          [payload.issue, addLinksToComment(payload.comment.url, payload.comment.id, payload.comment.body),
            entitiesForUpdate(payload.comment.body), []]
        else
          [{ number: undefined, title: undefined, html_url: undefined }, (->), [], []]
      
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
              (err, result, body) -> console.log "What? Got dat", body
          # For these, we fire off one POST to each entity type so the right one will take effect.
          for entityType in ['UserStories','Bugs','Tasks']
            targetProcess.post "#{entityType}/#{id}",
              Id: id
              EntityState:
                inProgressStateByType[entityType]
              CustomFields: [
                Name: "Pull Request"
                Value:
                  Url: issueUrl
                  Label: "##{issueNumber}: #{issueTitle}"
              ],
              (err, result, body) -> console.log "What? Got dat", body

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
              (err, result, body) -> console.log "What? Got dat", body

        linkAdderFn(robot, issueNumber, entityIdsToUpdate)

        res.send 200, "Fired off requests to update #{entityIdsToUpdate} and close #{entityIdsToClose} from PR #{issueNumber}."
      else
        res.send 400, "Expected an issue id but could not find one."

    catch exception
      console.log "It's all gone wrong:", exception, exception.stack
      res.send 500, "It's all gone wrong: #{Util.inspect exception}"
