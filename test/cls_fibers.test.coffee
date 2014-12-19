patchFibers = require '..'
{createNamespace} = require 'continuation-local-storage'
Fiber = require 'fibers'
Future = require 'fibers/future'
{expect} = require 'chai'

describe 'cls-fibers', ->
  {ns} = {}

  before ->
    ns = createNamespace 'test'
    patchFibers(ns)

  describe 'synchronous fiber', ->
    it 'keeps context isolated', ->
      ns.run ->
        Fiber ->
          ns.run ->
            ns.set 'data', 1
        .run()

        expect(ns.get 'data').not.to.be.ok

    it 'has access to scope where it was defined', ->
      ns.run ->
        ns.set 'data', 1
        Fiber ->
          expect(ns.get 'data').to.be.equal 1
        .run()

  describe 'yielding fiber', ->
    it 'keeps the context isolated', ->
      ns.run ->
        fiber = Fiber ->
          ns.run ->
            ns.set 'data', 1
            Fiber.yield()

        fiber.run()
        expect(ns.get 'data').not.to.be.ok


  describe 'concurrent fibers', ->
    it 'uses the active context', (done) ->

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
        expect(A.run()).to.equal 'B'
        done()

    it 'preserves context across Fiber::run', (done) ->

      A = Fiber ->
        ns.run ->
          ns.set 'func', 'A'
          Fiber.yield ns.get('func')
          Fiber.yield ns.get('func')

      B = Fiber ->
        ns.run ->
          ns.set 'func', 'B'
          Fiber.yield ns.get('func')

      ns.run ->
        expect(A.run()).to.equal 'A'
        expect(B.run()).to.equal 'B'
        expect(A.run()).to.equal 'A'
        done()
