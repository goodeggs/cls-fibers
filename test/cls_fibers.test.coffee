patchFibers = require '..'
{createNamespace} = require 'continuation-local-storage'
Fiber = require 'fibers'
{expect} = require 'chai'

describe 'cls-fibers', ->
  {ns} = {}

  beforeEach ->
    ns = createNamespace 'test'
    patchFibers(ns)

  it 'preserves context across Fiber::run', (done) ->

    A = Fiber ->
      ns.set 'func', 'A'
      Fiber.yield ns.get('func')
      Fiber.yield ns.get('func')
    
    B = Fiber ->
      ns.set 'func', 'B'
      Fiber.yield ns.get('func')
    
    ns.run ->
      expect(A.run()).to.equal 'A'
      expect(B.run()).to.equal 'B'
      expect(A.run()).to.equal 'A'
      done()

