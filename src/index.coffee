Fiber = require 'fibers'
FiberCLS = require './fiber_cls'

module.exports = (ns) ->
  runBefore = Fiber::run
  Fiber::run = (args...) ->
    cls = @__cls ?= new FiberCLS(ns)

    # Swap the CLS context chain, save a copy of the current chain for when the fiber yields.
    # Distinguish between fiber run for the first time, or a resume
    if cls.yielding
      cls.resume()
    else
      cls.run()

    try
      return runBefore.call @, args...
    finally
      unless cls.yielding
        cls.end()
        delete @__cls

  yieldBefore = Fiber.yield
  Fiber.yield = (args...) ->
    cls = Fiber.current?.__cls
    if cls
      cls.yield()

    yieldBefore(args...)
