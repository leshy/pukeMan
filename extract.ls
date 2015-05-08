_ = require 'underscore'
fs = require 'fs'

argv = process.argv
argv.shift()
argv.shift()

console.log 'files',argv

_.map argv, (file) ->
  console.log "reading", file
  data = fs.readFileSync(file)
  matched = String(data).match(/'(.*?)'|"(.*?)"/g)
  matched = _.map matched, (m) ->
    m = m.replace /\"/g, ''
    m = m.replace /\'/g, ''
  
  _.each matched, (m) -> process.stdout.write "'#{m}',"
  
