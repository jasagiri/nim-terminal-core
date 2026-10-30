# actors/actor_metrics.nim
## Metrics integration for actors

import std/times
import std/options
import actor
import widget_actor
import ../ninep/metrics_fs

export metrics_fs.UpdateActorStats, metrics_fs.ActorStats

type
  MetricsActor* = ref object of Actor
    ## Base actor with metrics collection
    startTime*: DateTime
    messagesIn*: int
    messagesOut*: int
    lastError*: string
    metricsServer*: Option[ActorRef]

proc initMetrics*(actor: MetricsActor) =
  ## Initialize metrics tracking
  actor.startTime = now()
  actor.messagesIn = 0
  actor.messagesOut = 0
  actor.lastError = ""

method processMessage*(actor: MetricsActor, msg: Message) {.async.} =
  ## Process message with metrics
  inc actor.messagesIn
  
  try:
    await procCall Actor(actor).processMessage(msg)
  except:
    actor.lastError = getCurrentExceptionMsg()
    raise
  
  # Report metrics if we have a server
  if actor.metricsServer.isSome:
    let stats = ActorStats(
      messagesReceived: actor.messagesIn,
      messagesSent: actor.messagesOut,
      lastError: actor.lastError,
      state: actor.state,
      uptime: (now() - actor.startTime).inSeconds.float
    )
    
    actor.metricsServer.get.castMessage(UpdateActorStats(
      actorId: actor.self.id,
      stats: stats
    ))

proc send*(actor: MetricsActor, target: ActorRef, msg: Message) =
  ## Send with metrics tracking
  inc actor.messagesOut
  target.send(msg)

# Widget metrics
type
  MetricsWidgetActor* = ref object of WidgetActor
    ## Widget with metrics
    startTime*: DateTime
    renderCount*: int
    lastRenderTime*: Duration
    metricsServer*: Option[ActorRef]

method render*(widget: MetricsWidgetActor, driver: AsyncDriver) {.async.} =
  ## Render with metrics
  let start = now()
  inc widget.renderCount
  
  await procCall WidgetActor(widget).render(driver)
  
  widget.lastRenderTime = now() - start
  
  # Report if we have a server
  if widget.metricsServer.isSome:
    widget.metricsServer.get.castMessage(UpdateMetric(
      key: fmt"widget.{widget.self.id}.render_count",
      value: $widget.renderCount
    ))
    widget.metricsServer.get.castMessage(UpdateMetric(
      key: fmt"widget.{widget.self.id}.last_render_ms",
      value: $widget.lastRenderTime.inMilliseconds
    ))

# Helper to enable metrics for any actor
proc enableMetrics*(actor: Actor, metricsServer: ActorRef) =
  ## Add metrics collection to an actor
  # Wrap processMessage
  let originalProcess = actor.processMessage
  var messagesIn = 0
  var messagesOut = 0
  let startTime = now()
  
  actor.processMessage = proc(a: Actor, msg: Message) {.async.} =
    inc messagesIn
    
    try:
      await originalProcess(a, msg)
    except:
      let stats = ActorStats(
        messagesReceived: messagesIn,
        messagesSent: messagesOut,
        lastError: getCurrentExceptionMsg(),
        state: a.state,
        uptime: (now() - startTime).inSeconds.float
      )
      
      metricsServer.castMessage(UpdateActorStats(
        actorId: a.self.id,
        stats: stats
      ))
      raise
    
    # Report stats periodically
    if messagesIn mod 100 == 0:  # Every 100 messages
      let stats = ActorStats(
        messagesReceived: messagesIn,
        messagesSent: messagesOut,
        lastError: "",
        state: a.state,
        uptime: (now() - startTime).inSeconds.float
      )
      
      metricsServer.castMessage(UpdateActorStats(
        actorId: a.self.id,
        stats: stats
      ))

# Convenience template
template withMetrics*(actorType: typedesc, metricsServer: ActorRef): untyped =
  ## Spawn actor with metrics enabled
  let actor = spawn(actorType)
  actor.enableMetrics(metricsServer)
  actor