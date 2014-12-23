{createNamespace} = require 'continuation-local-storage'
sinon = require 'sinon'
chai = require 'chai'
chai.use require 'sinon-chai'
expect = chai.expect
FiberCLS = require '../lib/fiber_cls'


describe 'FiberCLS', ->
  describe '::run', ->
    {ns} = {}

    beforeEach ->
      ns = createNamespace 'test.fibercls'
      sinon.spy ns, 'enter'

    afterEach ->
      ns.enter.restore()

    it 'saves the pre-fiber chain', ->
      ns.run ->
        cls = new FiberCLS(ns)
        cls.run()
        expect(cls.preservedChain).to.be.ok

    it 'enters the fiber context', ->
      ns.run ->
        sentinel = ns.active
        cls = new FiberCLS(ns)
        cls.run()
        expect(ns.enter).to.have.been.calledTwice
        expect(ns.enter).to.have.been.calledWith sentinel

  describe '::yield', ->
    {ns} = {}

    beforeEach ->
      ns = createNamespace 'test.fibercls'

    it 'saves the fiber chain', ->
      ns.run ->
        cls = new FiberCLS(ns)
        cls.run()
        cls.yield()
        expect(cls.fiberChain).to.be.ok

    it 'restores the preserved chain ', ->
      ns.run ->
        cls = new FiberCLS(ns)
        cls.run()
        restore = sinon.spy cls.preservedChain, 'restore'
        cls.yield()
        expect(restore).to.have.been.called
        expect(cls.preservedChain).not.to.be.ok

  describe '::resume', ->
    {ns} = {}

    beforeEach ->
      ns = createNamespace 'test.fibercls'

    it 'saves the pre-fiber chain', ->
      ns.run ->
        cls = new FiberCLS(ns)
        cls.run()
        cls.yield()
        cls.resume()
        expect(cls.preservedChain).to.be.ok

    it 'restores the fiber chain', ->
      ns.run ->
        cls = new FiberCLS(ns)
        cls.run()
        cls.yield()
        sinon.spy cls.fiberChain, 'restore'
        cls.resume()
        expect(cls.fiberChain.restore).to.have.been.called

  describe '::end', ->
    {ns} = {}

    beforeEach ->
      ns = createNamespace 'test.fibercls'

    it 'exits the fiber context', ->
      ns.run ->
        cls = new FiberCLS(ns)
        cls.run()
        sinon.spy ns, 'exit'
        cls.end()
        expect(ns.exit).to.have.been.calledWith cls.context

    it 'restores the preserved context', ->
      ns.run ->
        cls = new FiberCLS(ns)
        cls.run()
        restore = sinon.spy cls.preservedChain, 'restore'
        cls.end()
        expect(restore).to.have.been.called
        expect(cls.preservedChain).not.to.be.ok


    describe 'after resume', ->
      it 'exits the fiber context', ->
        ns.run ->
          cls = new FiberCLS(ns)
          cls.run()
          cls.yield()
          cls.resume()
          sinon.spy ns, 'exit'
          cls.end()
          expect(ns.exit).to.have.been.calledWith cls.context

      it 'restores the preserved context', ->
        ns.run ->
          cls = new FiberCLS(ns)
          cls.run()
          cls.yield()
          cls.resume()
          restore = sinon.spy cls.preservedChain, 'restore'
          cls.end()
          expect(restore).to.have.been.called
          expect(cls.preservedChain).not.to.be.ok
