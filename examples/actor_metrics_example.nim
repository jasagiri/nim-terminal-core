# actor_metrics_example.nim
## Example of actor-based app with 9P metrics

import std/asyncdispatch
import std/options
import std/strformat
import ../src/libterminal/actors/app_actor
import ../src/libterminal/actors/widget_actor
import ../src/libterminal/actors/actor_metrics
import ../src/libterminal/ninep/metrics_fs

when not defined(no9p):
  echo "9P metrics will be available on port 9999"
  echo "Access with: 9p -a localhost:9999 ls /metrics/"
else:
  echo "Compiled without 9P support (use -d:no9p to disable)"

# Custom actor that generates load
type
  WorkerActor = ref object of MetricsActor
    workInterval: int
    taskCount: int

proc newWorkerActor(interval = 100): WorkerActor =
  result = WorkerActor(workInterval: interval, taskCount: 0)
  result.initMetrics()

method init*(worker: WorkerActor) {.async.} =
  # Start work loop
  proc workLoop() {.async.} =
    while worker.state == asRunning:
      inc worker.taskCount
      worker.self.info(fmt"task_{worker.taskCount}")
      await sleepAsync(worker.workInterval)
  
  asyncCheck workLoop()

method handleInfo*(worker: WorkerActor, msg: Message) {.async.} =
  # Simulate work
  await sleepAsync(10)
  
  # Update app metric
  if worker.metricsServer.isSome:
    worker.metricsServer.get.castMessage(UpdateMetric(
      key: fmt"worker.{worker.self.id}.tasks",
      value: $worker.taskCount
    ))

# Run the app with metrics
runActorApp:
  let appRef = app
  
  when not defined(no9p):
    # Create metrics collector
    let metricsCollector = spawn(MetricsCollector, some(appRef))
    
    # Create 9P server
    let ninepServer = spawn(NinePServerActor, some(appRef))
    NinePServerActor(ninepServer).metricsCollector = metricsCollector
    
    # Enable metrics for the app itself
    AppActor(app).enableMetrics(metricsCollector)
  
  # Create main screen
  let mainScreen = spawn(ScreenActor, some(appRef))
  when not defined(no9p):
    ScreenActor(mainScreen).enableMetrics(metricsCollector)
  
  appRef.castMessage(RegisterScreen(name: "main", screen: mainScreen))
  
  # Create UI
  let ui = newUIBuilder(mainScreen)
  
  # Title and info
  let titleLabel = ui.label("Actor Metrics Demo", 10, 2)
  let infoLabel = ui.label("9P metrics available on localhost:9999", 10, 4)
  let helpLabel = ui.label("Press W to add worker, Q to quit", 10, 6)
  
  # Status display
  let statusLabel = ui.label("Workers: 0", 10, 8)
  let metricsLabel = ui.label("", 10, 10)
  
  # Add to screen
  let screen = ScreenActor(mainScreen)
  screen.addChild(titleLabel)
  screen.addChild(infoLabel)
  screen.addChild(helpLabel)
  screen.addChild(statusLabel)
  screen.addChild(metricsLabel)
  
  # Track workers
  var workers: seq[ActorRef] = @[]
  
  # Keyboard handler
  let eventHandler = proc(event: Event): Future[bool] {.async.} =
    if event.kind == ekKey:
      case event.key.kind
      of KeyEventKind.Char:
        case event.key.ch
        of 'w', 'W':
          # Spawn new worker
          let worker = spawn(WorkerActor, some(appRef))
          when not defined(no9p):
            WorkerActor(worker).metricsServer = some(metricsCollector)
          workers.add(worker)
          
          # Update status
          statusLabel.info(fmt"Workers: {workers.len}")
          await mainScreen.castMessage(RenderRequest(driver: AppActor(app).driver))
          return true
          
        of 'q', 'Q':
          # Stop all workers
          for w in workers:
            w.send(Message(kind: mkTerminate, reason: "User quit"))
          appRef.castMessage(StopApp())
          return true
          
        of 'm', 'M':
          # Show metrics info
          when not defined(no9p):
            metricsLabel.info("Try: 9p -a localhost:9999 read /metrics/actors/")
          else:
            metricsLabel.info("Metrics disabled (compile without -d:no9p)")
          await mainScreen.castMessage(RenderRequest(driver: AppActor(app).driver))
          return true
          
        else:
          discard
      else:
        discard
    return false
  
  AppActor(app).eventLoop.addHandler(ekKey, eventHandler)
  
  # Switch to main screen
  appRef.castMessage(SwitchScreen(name: "main"))
  
  # Show initial metrics hint
  when not defined(no9p):
    echo """
Metrics server started! Try these commands:

# List all metrics
9p -a localhost:9999 ls /metrics/

# See actor states
9p -a localhost:9999 ls /metrics/actors/

# Read specific metric
9p -a localhost:9999 read /metrics/actors/actor_1/state

# Monitor worker tasks
watch -n 1 '9p -a localhost:9999 read /metrics/app/worker.actor_*/tasks'
"""