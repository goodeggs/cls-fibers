Fiber = require 'fibers'

module.exports = (ns) ->
  runBefore = Fiber::run
  Fiber::run = (args...) ->
    context = ns.active
    ns.enter context
    try
      return runBefore.call @, args...
    finally
      ns.exit context

