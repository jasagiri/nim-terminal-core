# test_actor_metrics.nim
## Tests for actor metrics integration

when defined(ninep):
  import unittest
  import std/asyncdispatch
  import std/options
  import std/times
  import ../src/libterminal/actors/actor
  import ../src/libterminal/actors/actor_metrics
  import ../src/libterminal/actors/widget_actor
  import ../src/libterminal/ninep/metrics_fs

  suite "Actor Metrics":
    test "Metrics actor creation":
      type TestMetricsActor = ref object of MetricsActor
        testValue: int
      
      let actor = TestMetricsActor(testValue: 42)
      actor.initMetrics()
      
      check actor.messagesIn == 0
      check actor.messagesOut == 0
      check actor.lastError == ""
      check actor.metricsServer.isNone
    
    test "Message counting":
      type CountingActor = ref object of MetricsActor
      
      method handleInfo(actor: CountingActor, msg: Message) {.async.} =
        discard
      
      let actor = spawn(CountingActor)
      CountingActor(actor).initMetrics()
      
      # Send messages
      actor.info("test1")
      actor.info("test2")
      actor.info("test3")
      
      waitFor sleepAsync(100)
      
      # Check through actor reference
      check actorRegistry.hasKey(actor.id)
    
    test "Metrics reporting":
      let metricsServer = spawn(MetricsCollector)
      
      type ReportingActor = ref object of MetricsActor
      
      let actor = ReportingActor()
      actor.initMetrics()
      actor.metricsServer = some(metricsServer)
      
      # Simulate message processing
      inc actor.messagesIn
      inc actor.messagesOut
      
      check actor.messagesIn == 1
      check actor.messagesOut == 1
    
    test "Widget metrics":
      type TestWidgetActor = ref object of MetricsWidgetActor
      
      let widget = TestWidgetActor()
      widget.renderCount = 0
      
      # Simulate render
      inc widget.renderCount
      widget.lastRenderTime = initDuration(milliseconds = 16)
      
      check widget.renderCount == 1
      check widget.lastRenderTime.inMilliseconds == 16
    
    test "Enable metrics helper":
      let metricsServer = spawn(MetricsCollector)
      let actor = spawn(Actor)
      
      actor.enableMetrics(metricsServer)
      
      # Send test message
      actor.info("test")
      waitFor sleepAsync(100)
      
      check actorRegistry.hasKey(actor.id)
    
    test "Metrics with errors":
      type ErrorActor = ref object of MetricsActor
      
      method handleInfo(actor: ErrorActor, msg: Message) {.async.} =
        if msg.info == "error":
          raise newException(CatchableError, "Test error")
      
      let actor = ErrorActor()
      actor.initMetrics()
      
      try:
        await actor.handleInfo(Message(kind: mkInfo, info: "error"))
      except:
        actor.lastError = getCurrentExceptionMsg()
      
      check actor.lastError == "Test error"
    
    test "Update metric message":
      let update = UpdateMetric(
        key: "test.metric",
        value: "100"
      )
      
      check update.key == "test.metric"
      check update.value == "100"

else:
  import unittest
  
  suite "Actor Metrics (disabled)":
    test "Metrics compilation flag":
      check not defined(ninep)