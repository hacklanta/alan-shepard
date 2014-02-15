Util = require 'util'
_ = require 'underscore'

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

updateEntitiesIn = (string) ->
  entityIds =
    _.flatten(
      while match = updateRegex.exec(string) when match[1].match updateVerbs
        while entityMatch = entityRegex.exec(match[0])
          console.log "Booyan with an", entityMatch
          entityMatch[2] 
    )

  console.log 'Got dem', entityIds

updateOrCloseEntitiesIn = (string) ->
  [entityIdsToClose, entityIdsToUpdate] = [[], []]

  while match = updateRegex.exec(string)
    collection =
      if match[1].match updateVerbs
        entityIdsToUpdate
      else if match[1].match closeVerbs
        entityIdsToClose

    while entityMatch = entityRegex.exec(match[0])
      collection.push entityMatch[2]

  console.log 'Got dem', entityIdsToClose, entityIdsToUpdate

module.exports = (robot) ->
  robot.router.post '/target-process/pull-request', (req, res) ->
    try
      payload = JSON.parse req.param('payload')

      if payload.pull_request?.merged_at and payload.action? == 'closed'
        # Only close entities if the pull request has been merged and
        # we're closing it.
        updateOrCloseEntitiesIn payload.pull_request.body
      else if payload.pull_request?
        updateEntitiesIn payload.pull_request.body
      else if payload.comment?
        updateEntitiesIn payload.comment.body

    catch exception
      console.log "It's all gone wrong:", exception
      res.send 500, "It's all gone wrong: #{Util.inspect exception}"
