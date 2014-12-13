Fiber = require 'fibers'
Future = require 'fibers/future'

module.exports = (ns) ->
  runBefore = Fiber::run
  Fiber::run = (args...) ->
    context = @__cls ?= ns.createContext()
    ns.enter context
    try
      return runBefore.call @, args...
    finally
      ns.exit context


  resolveBefore = Future::resolve
  Future::resolve = (args...) ->
    [errorFuture, handler]  = args
    unless handler instanceof Function
      handler = errorFuture
      errorFuture = null

    context = ns.createContext()
    resolveArgs = []
    resolveArgs.push errorFuture if errorFuture
    resolveArgs.push ns.bind(handler, context)
    resolveBefore.apply @, resolveArgs
