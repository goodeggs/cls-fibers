CLSChain = require './cls_chain'

class FiberCLS
  constructor: (ns) ->
    @ns = ns
    @yielding = no

  run: ->
    # Save the pre-fiber (preserved) chain
    @preservedChain = new CLSChain(@ns)
    @context = @ns.active

    # Enter the fiber (active) context
    @ns.enter @context

  yield: ->
    @yielding = yes

    # Save the fiber chain
    if @fiberChain
      @fiberChain.save()
    @fiberChain ?= new CLSChain(@ns)

    # Restore preserved chain
    @preservedChain.restore()
    @preservedChain = null

  resume: ->
    @yielding = no

    # Save the non-fiber (preserved) chain
    @preservedChain = new CLSChain(@ns)

    # Restore the fiber chain
    @fiberChain.restore()

  end: ->
    # Exit the fiber context
    @ns.exit @context

    # Restore the preserved context
    @preservedChain.restore()
    @preservedChain = null
    @fiberChain = null

module.exports = FiberCLS
