patchFibers = require '..'
{createNamespace} = require 'continuation-local-storage'
Fiber = require 'fibers'
Future = require 'fibers/future'
{expect} = require 'chai'

describe 'cls-fibers', ->
  {ns} = {}

  describe 'Fiber::run', ->
    beforeEach ->
      ns = createNamespace 'test.fiber.run'
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

  describe 'Future::resolve', ->
    {ns} = {}

    beforeEach ->
      ns = createNamespace 'test.futures.resolve'
      patchFibers(ns)

    it 'runs in a new context based on where it was defined', (done) ->
      ns.run ->
        ns.set 'foo', 0
        future = new Future()

        resolveCalled = false
        future.resolve ->
          expect(ns.get 'foo').to.equal 1
          ns.set 'foo', 2
          resolveCalled = true

        ns.set 'foo', 1
        resolver = future.resolver()
        resolver()
        expect(resolveCalled).to.be.ok
        expect(ns.get 'foo').to.equal 1
        done()


    it 'each resolve has its own context', (done) ->
      ns.run ->
        resolversCalled = 0
        ns.set 'foo', 0
        future = new Future()

        resolver = future.resolver()
        future.resolve ->
          expect(ns.get 'foo').to.equal 1
          ns.set 'foo', 2
          resolversCalled++

        future.resolve ->
          expect(ns.get 'foo').to.equal 1
          ns.set 'foo', 2
          resolversCalled++

        ns.set 'foo', 1
        resolver()
        expect(resolversCalled).to.equal 2
        expect(ns.get 'foo').to.equal 1
        done()

    describe 'with two arguments', ->
      it 'wraps the second argument with its own context', (done) ->
        ns.run ->
          resolveCalled = false
          ns.set 'foo', 0
          future = new Future()
          errorFuture = new Future()
          errorFuture.resolve (err) ->
            done(err) # unexpected

          resolver = future.resolver()
          future.resolve errorFuture, (val) ->
            expect(ns.get 'foo').to.equal 1
            ns.set 'foo', 2
            resolveCalled = true

          ns.set 'foo', 1
          resolver()
          expect(resolveCalled).to.be.ok
          expect(ns.get 'foo').to.equal 1
          done()

  describe 'Future.wrap', ->
    {ns} = {}

    beforeEach ->
      ns = createNamespace 'test.future.wrap'
      patchFibers(ns)

    it 'runs in a new context', (done) ->
      ns.run ->
        ns.set 'foo', 0

        start = Future.wrap (callback) ->
          expect(ns.get 'foo').to.equal 1
          ns.set 'foo', 3
          process.nextTick ->
            callback(null, ns.get 'foo')

        ns.set 'foo', 1

        future = start()
        future.resolve (err, value) ->
          expect(value).to.equal 3
          expect(ns.get 'foo').to.equal 2
          done()

        ns.set 'foo', 2
