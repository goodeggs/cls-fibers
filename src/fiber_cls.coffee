assert = require 'assert'
CLSChain = require './cls_chain'

class FiberCLS
  constructor: (ns) ->
    @ns = ns
    @yielding = no
    @context = @ns.active

  run: ->
    assert !@fiberChain, 'FiberCLS::run should only be called once, when the fiber is run for the first time.'
    assert !@yielding, 'FiberCLS::run should only be called once, when the fiber is run for the first time.'
    # Save the pre-fiber (preserved) chain
    @preservedChain = new CLSChain(@ns)

    # Enter the fiber (active) context
    @ns.enter @context

  yield: ->
    assert !@yielding, 'FiberCLS::yield can only be called on a running fiber.'
    @yielding = yes

    # Save the fiber chain
    if @fiberChain
      @fiberChain.save()
    @fiberChain ?= new CLSChain(@ns)

    # Restore preserved chain
    @preservedChain.restore()
    @preservedChain = null

  resume: ->
    assert @yielding, 'FiberCLS::resume can only be called on a yielding fiber.'
    @yielding = no

    # Save the non-fiber (preserved) chain
    @preservedChain = new CLSChain(@ns)

    # Restore the fiber chain
    @fiberChain.restore()

  end: ->
    assert !@yielding, 'FiberCLS::end can only be called on a running fiber.'

    # Exit the fiber context
    @ns.exit @context

    # Restore the preserved context
    @preservedChain.restore()
    @preservedChain = null
    @fiberChain = null

module.exports = FiberCLS
