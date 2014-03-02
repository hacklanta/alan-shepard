# Description:
#   Sometimes, you want hubot to do things for you. It should snarkily reply with a meme in response.
#
# Commands:
#   hubot (do|make|fix|build|finish|commit|push|file)( the| my| me( a)) [thing] (for me)?
#
# Authors:
#   farmdawgnation
#   Hubot folks who wrote the imageMe plugin.
module.exports = (robot) ->
  robot.respond /(do|make|fix|build|finish|commit|push|file)( the| my| me( a)?)? ((.*) for me|.*)/i, (msg) ->
    subject =  (msg.match[5] || msg.match[4]) + " meme"
    imageMe msg, subject, (url) ->
      msg.send url

# Borrowed from the image me code.
imageMe = (msg, query, animated, faces, cb) ->
  cb = animated if typeof animated == 'function'
  cb = faces if typeof faces == 'function'
  q = v: '1.0', rsz: '8', q: query, safe: 'active'
  q.imgtype = 'animated' if typeof animated is 'boolean' and animated is true
  q.imgtype = 'face' if typeof faces is 'boolean' and faces is true
  msg.http('http://ajax.googleapis.com/ajax/services/search/images')
    .query(q)
    .get() (err, res, body) ->
      images = JSON.parse(body)
      images = images.responseData?.results
      if images?.length > 0
        image  = msg.random images
        cb "#{image.unescapedUrl}#.png"
