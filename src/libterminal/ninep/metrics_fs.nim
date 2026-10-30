# ninep/metrics_fs.nim
## Metrics filesystem for 9P server

import std/tables
import std/options
import std/strformat
import std/times
import server
import protocol
import ../actors/actor

type
  MetricsFS* = ref object of FileSystem
    ## Filesystem that exposes actor metrics
    root*: File
    actorStats*: ptr Table[string, ActorStats]
    appMetrics*: ptr Table[string, string]

proc createActorFiles(stats: ActorStats): Table[string, File] =
  ## Create virtual files for actor stats
  result = initTable[string, File]()
  
  result["state"] = newFile("state", false, 
    proc(): string = $stats.state
  )
  
  result["messages_in"] = newFile("messages_in", false,
    proc(): string = $stats.messagesReceived
  )
  
  result["messages_out"] = newFile("messages_out", false,
    proc(): string = $stats.messagesSent
  )
  
  result["uptime"] = newFile("uptime", false,
    proc(): string = fmt"{stats.uptime:.2f}s"
  )
  
  result["last_error"] = newFile("last_error", false,
    proc(): string = stats.lastError
  )

proc buildFileTree*(fs: MetricsFS) =
  ## Build/rebuild the file tree from current metrics
  # Clear existing actor entries
  if "actors" in fs.root.children:
    fs.root.children["actors"].children.clear()
  else:
    let actorsDir = newFile("actors", true)
    fs.root.addChild("actors", actorsDir)
  
  # Add actor metrics
  if fs.actorStats != nil:
    for actorId, stats in fs.actorStats[]:
      let actorDir = newFile(actorId, true)
      for name, file in createActorFiles(stats):
        actorDir.addChild(name, file)
      fs.root.children["actors"].addChild(actorId, actorDir)
  
  # Add app metrics
  if "app" notin fs.root.children:
    let appDir = newFile("app", true)
    fs.root.addChild("app", appDir)
  
  if fs.appMetrics != nil:
    for key, value in fs.appMetrics[]:
      let file = newFile(key, false,
        proc(): string = value
      )
      fs.root.children["app"].addChild(key, file)

method getFile*(fs: MetricsFS, path: string): Option[File] =
  ## Get file by path
  # Rebuild tree to get latest metrics
  fs.buildFileTree()
  
  if path == "/":
    return some(fs.root)
  
  let parts = path.split("/")[1..^1]  # Skip empty first element
  var current = fs.root
  
  for part in parts:
    if part == "":
      continue
    if not current.isDir:
      return none(File)
    if part notin current.children:
      return none(File)
    current = current.children[part]
  
  return some(current)

proc newMetricsFS*(actorStats: ptr Table[string, ActorStats],
                   appMetrics: ptr Table[string, string]): MetricsFS =
  ## Create new metrics filesystem
  result = MetricsFS(
    root: newFile("/", true),
    actorStats: actorStats,
    appMetrics: appMetrics
  )
  
  # Create base structure
  result.root.addChild("actors", newFile("actors", true))
  result.root.addChild("app", newFile("app", true))
  
  # Add static files
  result.root.addChild("version", newFile("version", false,
    proc(): string = "libterminal metrics v1.0"
  ))

# Integration with actor system
type
  MetricsCollector* = ref object of Actor
    ## Actor that collects metrics
    stats*: Table[string, ActorStats]
    appMetrics*: Table[string, string]
    updateInterval*: int  # milliseconds

proc newMetricsCollector*(updateInterval = 1000): MetricsCollector =
  result = MetricsCollector(
    stats: initTable[string, ActorStats](),
    appMetrics: initTable[string, string](),
    updateInterval: updateInterval
  )

method init*(collector: MetricsCollector) {.async.} =
  ## Start periodic collection
  proc collectLoop() {.async.} =
    while collector.state == asRunning:
      # Request stats from all actors
      collector.self.info("collect")
      await sleepAsync(collector.updateInterval)
  
  asyncCheck collectLoop()

method handleInfo*(collector: MetricsCollector, msg: Message) {.async.} =
  case msg.info
  of "collect":
    # Update app metrics
    collector.appMetrics["timestamp"] = $now()
    collector.appMetrics["actor_count"] = $collector.stats.len
  else:
    discard

method handleCast*(collector: MetricsCollector, msg: Message) {.async.} =
  if msg.castPayload != nil:
    try:
      let update = cast[ptr UpdateActorStats](msg.castPayload)[]
      collector.stats[update.actorId] = update.stats
    except:
      discard

# 9P Server Actor
type
  NinePServerActor* = ref object of Actor
    ## Actor wrapper for 9P server
    server*: NinePServer
    port*: int
    metricsCollector*: ActorRef

proc newNinePServerActor*(port = 9999, collector: ActorRef): NinePServerActor =
  result = NinePServerActor(
    port: port,
    metricsCollector: collector
  )

method init*(actor: NinePServerActor) {.async.} =
  ## Start 9P server
  # Get collector reference
  let collector = MetricsCollector(actor.metricsCollector)
  
  # Create filesystem
  let fs = newMetricsFS(
    addr collector.stats,
    addr collector.appMetrics
  )
  
  # Create and start server
  actor.server = newNinePServer(fs)
  asyncCheck actor.server.serve(actor.port)

method terminate*(actor: NinePServerActor, reason: string) {.async.} =
  ## Stop server
  if actor.server != nil:
    actor.server.running = false
    if actor.server.socket != nil:
      actor.server.socket.close()