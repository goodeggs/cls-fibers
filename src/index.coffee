Fiber = require 'fibers'
assert = require 'assert'

# TODO Too heavy?
class CLSChain
  constructor: (ns) ->
    @ns = ns
    @active = ns.active

    # Copy the context set
    @_set = [].concat ns._set

  save: ->
    @active = @ns.active
    assert.equal @_set, @ns._set, "Another CLS chain has already been resumed"

  resume: ->
    @ns.active = @active
    @ns._set = @_set


module.exports = (ns) ->
  runBefore = Fiber::run
  Fiber::run = (args...) ->
    # Swap the CLS context chain, save a copy of the current chain for when the fiber yields.
    preservedChain = new CLSChain(ns)
    @__fiberChain ?= new CLSChain(ns)
    @__fiberChain.resume()
    context = @__fiberChain.active
    ns.enter context
    try
      return runBefore.call @, args...
    finally
      #TODO optimize for the fiber being done vs yielding. If the fiber is done, no need to save the chain.
      @__fiberChain.save()
      ns.exit context
      preservedChain.resume()

