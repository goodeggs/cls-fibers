Fiber = require 'fibers'

# TODO Too heavy?
class CLSChain
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
    preservedChain = new CLSChain(ns)
    if @__fiberChain
      # Resuming the fiber, resume the CLS chain as well
      @__fiberChain.resume()
    context = ns.active
    ns.enter context
    try
      return runBefore.call @, args...
    finally
      #TODO optimize for the fiber being done vs yielding. If the fiber is done, no need to save the chain.
      @__fiberChain = new CLSChain(ns)
      ns.exit context
      preservedChain.resume()

