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

  describe 'fiber runs', ->
    it 'reads from the active context', ->
        ns.run ->
          ns.set 'data', 1
          sentinel = ns.active
          Fiber ->
            expect(ns.get 'data').to.equal 1
            expect(ns.active).to.equal sentinel
          .run()

  describe 'fiber ends', ->
    it 'writes to the active context', ->
      sentinel = null
      ns.run ->
        Fiber ->
          ns.set 'data', 1
          sentinel = ns.active
        .run()
        expect(ns.get 'data').to.equal 1
        expect(ns.active).to.equal sentinel

  describe 'fiber yields', ->
    describe 'inside parent context', ->
      it 'shares the active context', ->
        sentinel = null
        ns.run ->
          Fiber ->
            ns.set 'data', 1
            sentinel = ns.active
            Fiber.yield()
          .run()
          expect(ns.get 'data').to.equal 1
          expect(ns.active).to.equal sentinel

    describe 'inside a child context', ->
      it 'preserves the context before the fiber', ->
        ns.run ->
          sentinel = ns.active
          Fiber ->
            ns.run ->
              ns.set 'data', 1
              Fiber.yield()
          .run()
          expect(ns.get 'data').not.to.be.ok
          expect(ns.active).to.equal sentinel

  describe 'fiber resumes', ->
    describe 'from yield in child context', ->
      it 'has the context where it yielded', ->
        ns.run ->
          fiber = Fiber ->
            ns.run ->
              ns.set 'data', 1
              sentinel = ns.active
              Fiber.yield()
              expect(ns.get 'data').to.equal 1
              expect(ns.active).to.equal sentinel

          fiber.run()
          fiber.run()

    describe 'from yield in parent context', ->
      it 'has modifications made during the yield', ->
        ns.run ->
          fiber = Fiber ->
            Fiber.yield()
            expect(ns.get 'data').to.equal 1
            expect(ns.active).to.equal sentinel

          fiber.run()
          ns.set 'data', 1
          sentinel = ns.active
          fiber.run()

    describe 'with chained contexts', ->
      it 'uses the context from the yield point', ->
        ns.run ->
          fiber = Fiber ->
            sentinel = ns.active
            ns.run ->
              ns.set 'data', 1
              Fiber.yield()

            expect(ns.get 'data').not.to.be.ok
            expect(ns.active).to.equal sentinel

          fiber.run()
          fiber.run()


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
