h = require 'helpers'
_ = require 'underscore'

rndName = -> h.rndid(5)

class Context
  (@expressions) -> true
  expression: ->
    

e_number = -> String h.RandomInt(1000)

e_var = (context) ->
  name = rndName()
  
  val = "var #{ name } = " + context.expression()
  context.push name
  val

e_plus = (context) ->
  context.expresion() + " + " + context.expresion()


e_function = (e) ->
  name = rndName()
  val = "function #{name} {"
  
  e.depth++



e_function = (context) ->
  name = rndName()
  context.depth++

  context.push
    e_function_call = (context) ->
      return name + "()"
    
  
  "\nfunction " + name + "() {\nreturn " + context.expression() + "\n};\n" 


context =
  expressions: [ e_var, e_plus, e_number, e_function ]
  depth: 0
  
console.log expression(context)
console.log expression(context)
console.log expression(context)
console.log expression(context)
