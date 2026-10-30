# metrics/ninep_actor.nim
## 9P protocol support for metrics export

import std/tables
import std/strformat
import std/options
import ../actors/actor

type
  NinePActor* = ref object of Actor
    ## 9P server actor for metrics
    port*: int
    metrics*: Table[string, string]
    actorStats*: Table[string, ActorStats]
    
  ActorStats* = object
    messagesReceived*: int
    messagesSent*: int
    lastError*: string
    state*: ActorState
    uptime*: float
    
  FileNode* = object
    name*: string
    case kind*: FileKind
    of fkDir:
      children*: Table[string, FileNode]
    of fkFile:
      content*: proc(): string
      
  FileKind* = enum
    fkDir
    fkFile

proc newNinePActor*(port = 9999): NinePActor =
  result = NinePActor(
    port: port,
    metrics: initTable[string, string](),
    actorStats: initTable[string, ActorStats]()
  )

method init*(server: NinePActor) {.async.} =
  ## Initialize 9P server
  # Setup virtual filesystem
  # /metrics/
  #   actors/
  #     <actor_id>/
  #       state
  #       messages_in
  #       messages_out
  #       uptime
  #   app/
  #     fps
  #     memory
  #     widgets_count
  discard

proc buildFileTree*(server: NinePActor): FileNode =
  ## Build virtual filesystem from metrics
  result = FileNode(
    name: "metrics",
    kind: fkDir,
    children: initTable[string, FileNode]()
  )
  
  # Add actors directory
  var actorsDir = FileNode(
    name: "actors", 
    kind: fkDir,
    children: initTable[string, FileNode]()
  )
  
  for actorId, stats in server.actorStats:
    var actorDir = FileNode(
      name: actorId,
      kind: fkDir, 
      children: initTable[string, FileNode]()
    )
    
    # Add stat files
    actorDir.children["state"] = FileNode(
      name: "state",
      kind: fkFile,
      content: proc(): string = $stats.state
    )
    
    actorDir.children["messages_in"] = FileNode(
      name: "messages_in",
      kind: fkFile,
      content: proc(): string = $stats.messagesReceived
    )
    
    actorDir.children["uptime"] = FileNode(
      name: "uptime",
      kind: fkFile,
      content: proc(): string = fmt"{stats.uptime:.2f}s"
    )
    
    actorsDir.children[actorId] = actorDir
  
  result.children["actors"] = actorsDir

# Message types
type
  UpdateActorStats* = object
    actorId*: string
    stats*: ActorStats
    
  UpdateMetric* = object
    key*: string
    value*: string

method handleCast*(server: NinePActor, msg: Message) {.async.} =
  if msg.castPayload == nil:
    return
    
  try:
    let update = cast[ptr UpdateActorStats](msg.castPayload)[]
    server.actorStats[update.actorId] = update.stats
  except:
    discard
    
  try:
    let update = cast[ptr UpdateMetric](msg.castPayload)[]
    server.metrics[update.key] = update.value
  except:
    discard

# Integration with actor system
proc enableMetrics*(actor: Actor, metricsServer: ActorRef) =
  ## Enable metrics collection for an actor
  # Override processMessage to collect stats
  let originalProcess = actor.processMessage
  
  actor.processMessage = proc(a: Actor, msg: Message) {.async.} =
    # Update stats
    var stats = ActorStats(
      messagesReceived: 1,  # Increment
      state: a.state,
      uptime: 0.0  # Calculate from start time
    )
    
    metricsServer.castMessage(UpdateActorStats(
      actorId: a.self.id,
      stats: stats
    ))
    
    # Call original
    await originalProcess(a, msg)