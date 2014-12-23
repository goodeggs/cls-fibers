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

  restore: ->
    @ns.active = @active
    @ns._set = @_set

module.exports = CLSChain
