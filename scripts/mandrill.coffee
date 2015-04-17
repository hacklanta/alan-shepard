# Description:
#   Interact with Mandrill remotely
#
# Dependencies:
#   mandrill-api
#
# Configuration:
#   MANDRILL_TOKEN - Mandrill API Auth token 
#
# Commands:
#   hubot (mandrill|email) (blacklog|queue) - Show current backlog for hubot accounts
#
# Author: 
#   @riveramj

rawMandrillTokens = process.env.MANDRILL_TOKEN
mandrillTokenPairs = rawMandrillTokens.split(',')
mandrillTokens = for pair in mandrillTokenPairs
                   pair.split(':')

mandrillApi = require 'mandrill-api/mandrill'

mandrillClients = for token in mandrillTokens
                    [token[0], new mandrillApi.Mandrill(token[1])]

module.exports = (robot) ->

  getUsersForAllAccounts = (msg) ->
    for client in mandrillClients
      do (client) ->
        client[1].users.info {}, (user) ->
          msg.send "#{client[0]} : #{user.backlog}"

  robot.respond /(mandrill|email) (backlog|queue)/i, (msg) ->
    getUsersForAllAccounts msg

  robot.respond /find email (?:with|that contains) (.*)/i, (msg) ->
    query = msg.match[1].trim()
    dateFrom = "2015-04-17"
    dateTo = "2015-04-17"

    mandrillClients[0][1].messages.search {"query": query, "date_from": dateFrom, "date_to": dateTo}, (emails)  ->
      if emails.length > 0
        for email in emails
          do (email) ->
            date = new Date(email.ts * 1000)
            msg.send """
              to: #{email.email}
              subject: #{email.subject}
              sent: #{date}
              state: #{email.state}
              account: #{email.subaccount}
            """
      else
        msg.send "Did not find any emails"
