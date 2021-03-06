esfuzz = require 'esfuzz'
escodegen = require 'escodegen'

ast = esfuzz.generate maxDepth: 20

format =
  indent:
    style: "  "
    base: 1
  quotes: 'auto'
  escapeless: true
  compact: false
  parentheses: true
  semicolons: false

console.log escodegen.generate ast, verbatim: 'raw', format: format
