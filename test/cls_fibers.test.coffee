patchFibers = require '..'
{createNamespace} = require 'continuation-local-storage'
Fiber = require 'fibers'
Future = require 'fibers/future'
{expect} = require 'chai'
assert = require 'assert'

describe 'cls-fibers', ->
  {ns} = {}

  describe 'Fiber::run2', ->
    beforeEach ->
      ns = createNamespace 'test.fiber.run'
      patchFibers(ns)

    ctx = (name) ->
      previous = ns.get('path') or []
      # Treat as a Set (copy of array)
      path = [name].concat previous
      ns.set 'path', path
      console.log {start: name, path, set: ns._set}
      ->
        path = ns.get 'path'
        pop = path.shift()
        console.log {end: name, path, set: ns._set}
        # Restore the previous Set.
        ns.set 'path', previous
        assert.equal pop, name, 'context was not at the top of the stack'

    next = process.nextTick.bind(process)

    describe 'nextTick', ->
      it 'handles children', (done) ->
        # deep tree (line, child)
        # {} - {} - {} - {}
        # root - A - B - C
        ns.run ->
          endRoot = ctx 'root'
          next ->
            endA = ctx 'A'
            next ->
              endB = ctx 'B'
              next ->
                endC = ctx 'C'
                endC()
                endB()
                endA()
                endRoot()
                done()

      it 'handles siblings', (done) ->
        # branch (sibling)
        # {} - {} - {} - {}
        #   \
        #     {}
        #
        # root - A - B - C
        #   \
        #     - A' - B' - C'
        ns.run ->
          endRoot = ctx 'root'
          pending = 2
          tryDone = ->
            if --pending is 0
              endRoot()
              done()

          ns.run ->
            next ->
              endA = ctx 'A'
              next ->
                endB = ctx 'B'
                next ->
                  endC = ctx 'C'
                  endC()
                  endB()
                  endA()
                  tryDone()

          ns.run ->
            next ->
              endA = ctx "A^"
              next ->
                endB = ctx "B^"
                next ->
                  endC = ctx 'C^'
                  endC()
                  endB()
                  endA()
                  tryDone()


          # For fibers...
          #
          # When a fiber runs for the first time, we want a new state (a child
          # of the active one probably). We should save the previous state so
          # that we can restore it when the fiber yields.  When the fiber
          # yields, we save the fiber state. With the fiber yielded, we want
          # the previous state to be active, so we should restore the previous
          # state.
          #
          # When the fiber runs again, we want to restore the saved fiber
          # state. It's not just a single context that should be restored, it's
          # the whole state.  The fiber context (when the fiber started) wont't
          # always be at the top of the stack, it's possible additional
          # contexts were created* during the fiber run, so the active one
          # should be whatever context that was active when the fiber yielded.
          #
          # I'm purposefully avoiding the words "enter/exit" and "context"
          # because I don't think that's really what we're talking about. We're
          # not pushing/poping individual contexts, we're swapping out a whole
          # stack of contexts... I think.
          #
          # * So maybe in theory contexts might be added to the stack during a
          # fiber run, but wouldn't that mean something was actually put on the
          # event loop? In which case it would no longer be in the fiber. This
          # is either a corner case we need to code for, or a chance for
          # optimization.

    xit 'pops on yield', (done) ->
      ctx = (name) ->
        console.log "before #{name}: #{ns.get 'ctx'}"
        ns.set 'ctx', name

      A = Future.wrap (callback) ->
        ctx 'enter future'
        setTimeout ->
          ctx 'exit future'
          callback()
        , 50
        ctx 'yield future'

      queueWork ->
        blah()
        blah()
        setTiemout ->
          done()
      ns.run ->
        ctx 'before run'
        setTimeout ->
          ctx 'enter'
        , 1
        Fiber ->
          #sync
          ctx 'enter fiber'

          #async
          A().wait()
          ctx 'exit fiber'
        .run()
        ctx 'after run'


  xdescribe 'Fiber::run', ->
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

  xdescribe 'Future::resolve', ->
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

    xdescribe 'with two arguments', ->
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

  xdescribe 'Future.wrap', ->
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

  xdescribe 'concurrent fibers', ->
    beforeEach ->
      ns = createNamespace 'test.fibers.concurrent'
      patchFibers(ns)

    it 'isolates context between fibers', (done) ->

      A = Future.wrap (callback) ->
          ns.set 'func', 'A'
          setTimeout ->
            callback null, ns.get('func')
          , 50

      B = Future.wrap (callback) ->
          ns.set 'func', 'B'
          setTimeout ->
            callback null, ns.get('func')
          , 25

      ns.run ->
        #afuture = new Future()
        #bfuture = new Future()

        pending = 2
        maybeDone = (err) ->
          done(err) if err
          done() if --pending is 0

        A().resolve (err, a) ->
          ns.get 'func'
          expect(a).to.equal 'A'
          maybeDone(err)

        B().resolve (err, b) ->
          expect(b).to.equal 'B'
          maybeDone(err)
