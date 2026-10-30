# actors/actor.nim
## Actor-based architecture for terminal UI

import std/asyncdispatch
import std/tables
import std/options
import std/deques
import std/times
import std/locks
import std/sequtils

type
  # Thread-safe message channel
  MessageChannel*[T] = object
    queue: Deque[T]
    lock: Lock
    cond: Cond

  ActorState* = enum
    asStarting
    asRunning
    asStopping
    asStopped
    
  MessageKind* = enum
    mkCall      # Synchronous call expecting reply
    mkCast      # Asynchronous message  
    mkInfo      # String info message
    mkReply     # Reply to call
    mkExit      # Exit signal
    mkInit      # Initialize actor
    mkTerminate # Terminate actor

  # Forward declare for circular dependency
  ActorRef* = ref object
    ## Reference to an actor
    id*: string
    mailbox*: ptr MessageChannel[Message]
    
  Message* = object
    ## Message passed between actors
    sender*: Option[ActorRef]
    case kind*: MessageKind
    of mkCall:
      callId*: string
      callPayload*: pointer
    of mkCast:
      castPayload*: pointer
    of mkInfo:
      info*: string
    of mkReply:
      replyId*: string
      replyPayload*: pointer
    of mkExit:
      reason*: string
    of mkInit:
      discard
    of mkTerminate:
      termReason*: string
    
  Actor* = ref object of RootObj
    ## Base actor type
    self*: ActorRef
    state*: ActorState
    supervisor*: Option[ActorRef]
    children*: seq[ActorRef]
    mailbox: Deque[Message]
    processMessage*: proc(actor: Actor, msg: Message) {.async.}
    
  SupervisorStrategy* = enum
    ssOneForOne    # Restart only failed child
    ssOneForAll    # Restart all children
    ssRestForOne   # Restart failed child and younger siblings
    
  RestartStrategy* = object
    maxRestarts*: int
    withinSeconds*: int
    
  Supervisor* = ref object of Actor
    ## Supervisor actor that manages children
    strategy*: SupervisorStrategy
    restartStrategy*: RestartStrategy
    restartHistory: seq[DateTime]

  TimeoutError* = object of CatchableError

proc newMessageChannel*[T](): ptr MessageChannel[T] =
  result = create(MessageChannel[T])
  result.queue = initDeque[T]()
  initLock(result.lock)
  initCond(result.cond)

proc send*[T](ch: ptr MessageChannel[T], msg: T) =
  withLock(ch.lock):
    ch.queue.addLast(msg)
    signal(ch.cond)

proc tryRecv*[T](ch: ptr MessageChannel[T]): tuple[hasMsg: bool, msg: T] =
  withLock(ch.lock):
    if ch.queue.len > 0:
      result = (true, ch.queue.popFirst())
    else:
      result = (false, default(T))

# Global actor registry
var actorRegistry* {.threadvar.}: Table[string, ActorRef]
var actorIdCounter {.threadvar.}: int

proc genActorId(): string =
  inc actorIdCounter
  result = "actor_" & $actorIdCounter

proc newActorRef*(id = ""): ActorRef =
  result = ActorRef(
    id: if id == "": genActorId() else: id,
    mailbox: newMessageChannel[Message]()
  )
  actorRegistry[result.id] = result

proc send*(actor: ActorRef, msg: Message) =
  ## Send a message to an actor
  actor.mailbox.send(msg)

proc call*[T](actor: ActorRef, payload: T, 
              timeout = 5000): Future[Message] {.async.} =
  ## Synchronous call to actor
  let callId = genActorId()
  let replyBox = newMessageChannel[Message]()
  
  var msg = Message(
    kind: mkCall,
    callId: callId,
    sender: some(ActorRef(id: callId, mailbox: replyBox))
  )
  msg.callPayload = cast[pointer](unsafeAddr payload)
  
  actor.send(msg)
  
  # Wait for reply with timeout
  let start = now()
  while true:
    let (hasMsg, reply) = replyBox.tryRecv()
    if hasMsg:
      return reply
    
    if (now() - start).inMilliseconds > timeout:
      raise newException(TimeoutError, "Actor call timeout")
    
    await sleepAsync(10)

proc castMessage*[T](actor: ActorRef, payload: T) =
  ## Asynchronous message to actor
  var msg = Message(kind: mkCast)
  msg.castPayload = cast[pointer](unsafeAddr payload)
  actor.send(msg)

proc info*(actor: ActorRef, text: string) =
  ## Send info message
  actor.send(Message(kind: mkInfo, info: text))

# Actor methods to override
method init*(actor: Actor) {.base, async.} =
  ## Called when actor starts
  discard

method handleCall*(actor: Actor, msg: Message): Future[Message] {.base, async.} =
  ## Handle synchronous calls
  return Message(kind: mkReply, replyId: msg.callId)

method handleCast*(actor: Actor, msg: Message) {.base, async.} =
  ## Handle async messages
  discard

method handleInfo*(actor: Actor, msg: Message) {.base, async.} =
  ## Handle info messages
  discard

method terminate*(actor: Actor, reason: string) {.base, async.} =
  ## Called when actor stops
  discard

proc defaultProcessMessage(actor: Actor, msg: Message) {.async.} =
  case msg.kind
  of mkInit:
    await actor.init()
  of mkCall:
    let reply = await actor.handleCall(msg)
    if msg.sender.isSome:
      msg.sender.get.send(reply)
  of mkCast:
    await actor.handleCast(msg)
  of mkInfo:
    await actor.handleInfo(msg)
  of mkTerminate:
    await actor.terminate(msg.termReason)
    actor.state = asStopped
  else:
    discard

proc run*(actor: Actor) {.async.} =
  ## Main actor loop
  actor.state = asStarting
  actor.self.send(Message(kind: mkInit))
  actor.state = asRunning
  
  while actor.state == asRunning:
    # Process messages
    let (hasMsg, msg) = actor.self.mailbox.tryRecv()
    if hasMsg:
      try:
        await actor.processMessage(actor, msg)
      except:
        # Handle errors - notify supervisor
        if actor.supervisor.isSome:
          actor.supervisor.get.send(Message(
            kind: mkExit,
            reason: getCurrentExceptionMsg()
          ))
    else:
      await sleepAsync(1)
  
  # Clean up when actor stops
  if actorRegistry.hasKey(actor.self.id):
    actorRegistry.del(actor.self.id)

proc spawn*[T: Actor](actorType: typedesc[T], 
                      supervisor: Option[ActorRef] = none(ActorRef)): ActorRef =
  ## Spawn a new actor
  let actor = T()
  actor.self = newActorRef()
  actor.supervisor = supervisor
  actor.state = asStarting
  actor.children = @[]
  actor.processMessage = defaultProcessMessage
  
  # Start actor loop
  asyncCheck actor.run()
  
  return actor.self

# Supervisor implementation
proc newSupervisor*(strategy = ssOneForOne, 
                    maxRestarts = 3, 
                    withinSeconds = 60): Supervisor =
  result = Supervisor(
    strategy: strategy,
    restartStrategy: RestartStrategy(
      maxRestarts: maxRestarts,
      withinSeconds: withinSeconds
    ),
    restartHistory: @[]
  )
  result.processMessage = defaultProcessMessage

method handleExit(sup: Supervisor, childRef: ActorRef, reason: string) {.async.} =
  ## Handle child exit
  # Check restart strategy
  let now = now()
  sup.restartHistory = sup.restartHistory.filterIt(
    (now - it).inSeconds < sup.restartStrategy.withinSeconds
  )
  
  if sup.restartHistory.len >= sup.restartStrategy.maxRestarts:
    # Too many restarts - escalate to our supervisor
    if sup.supervisor.isSome:
      sup.supervisor.get.send(Message(
        kind: mkExit,
        reason: "Child restart limit exceeded"
      ))
    return
  
  sup.restartHistory.add(now)
  
  # Restart based on strategy
  case sup.strategy
  of ssOneForOne:
    # Restart only the failed child
    discard
  of ssOneForAll:
    # Restart all children
    discard  
  of ssRestForOne:
    # Restart failed child and younger siblings
    discard