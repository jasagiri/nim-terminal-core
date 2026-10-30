# test_actors.nim
## Tests for actor-based system

import unittest
import std/asyncdispatch
import std/options
import std/times
import std/tables
import ../src/libterminal/actors/actor
import ../src/libterminal/actors/widget_actor
import ../src/libterminal/actors/app_actor

# Define test actors at top level
type 
  TestActor = ref object of Actor
    receivedMessages: seq[string]

  CallRequest = object
    value: int
  CallResponse = object
    doubled: int
  CalcActor = ref object of Actor
  
  LifecycleActor = ref object of Actor
    initialized: bool
    terminated: bool

proc newTestActor(): TestActor =
  result = TestActor(receivedMessages: @[])

method handleInfo(actor: TestActor, msg: Message) {.async.} =
  actor.receivedMessages.add(msg.info)

method handleCall(actor: CalcActor, msg: Message): Future[Message] {.async.} =
  let req = cast[ptr CallRequest](msg.callPayload)[]
  var resp = CallResponse(doubled: req.value * 2)
  result = Message(kind: mkReply, replyId: msg.callId)
  result.replyPayload = cast[pointer](addr resp)

method init(actor: LifecycleActor) {.async.} =
  actor.initialized = true

method terminate(actor: LifecycleActor, reason: string) {.async.} =
  actor.terminated = true

suite "Actor System":
  test "Actor creation and messaging":
    # Test
    let actor = spawn(TestActor)
    actor.info("test1")
    actor.info("test2")
    
    # Wait for processing
    waitFor sleepAsync(100)
    
    # Verify through registry
    check actorRegistry.hasKey(actor.id)
  
  test "Synchronous calls":
    # Test
    let actor = spawn(CalcActor)
    let req = CallRequest(value: 21)
    let reply = waitFor actor.call(req, timeout=1000)
    
    check reply.kind == mkReply
  
  test "Actor lifecycle":
    # Test
    let actor = spawn(LifecycleActor)
    waitFor sleepAsync(100)  # Wait for init
    
    actor.send(Message(kind: mkTerminate, termReason: "test"))
    waitFor sleepAsync(100)  # Wait for terminate
    
    # Check state through registry
    check not actorRegistry.hasKey(actor.id)  # Should be removed after termination

suite "Supervisor":
  test "Supervisor creation":
    let sup = newSupervisor(ssOneForOne, maxRestarts=3, withinSeconds=60)
    check sup.strategy == ssOneForOne
    check sup.restartStrategy.maxRestarts == 3
    check sup.restartStrategy.withinSeconds == 60
  
  test "Restart strategies":
    let sup = newSupervisor(ssOneForAll)
    check sup.strategy == ssOneForAll
    
    let sup2 = newSupervisor(ssRestForOne)
    check sup2.strategy == ssRestForOne

suite "Widget Actors":
  test "Label actor":
    let label = newLabelActor("Test Label")
    check label.text == "Test Label"
    check label.visible == true
  
  test "Button actor":
    let button = newButtonActor("Click Me")
    check button.label == "Click Me"
    check button.visible == true
    check button.onClick.isNone
  
  test "Container actor":
    let container = newContainerActor()
    check container.visible == true
    check container.childWidgets.len == 0

suite "App Actor":
  test "App creation":
    let app = newAppActor("Test App")
    check app.title == "Test App"
    check not app.running
    check app.screens.len == 0
    check app.currentScreen.isNone
  
  test "Screen creation":
    let screen = newScreenActor("Main")
    check screen.name == "Main"
    check screen.visible == true
    check screen.childWidgets.len == 0