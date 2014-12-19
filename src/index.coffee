Fiber = require 'fibers'

# TODO Too heavy?
class Stack
  constructor: (ns) ->
    @ns = ns
    @active = ns.active

    # Copy the context set
    @_set = [].concat ns._set

  resume: ->
    @ns.active = @active
    @ns._set = @_set


module.exports = (ns) ->
  runBefore = Fiber::run
  Fiber::run = (args...) ->
    preservedStack = new Stack(ns)
    context = @__cls ?= ns.active
    ns.enter context
    try
      return runBefore.call @, args...
    finally
      ns.exit context
      preservedStack.resume()

