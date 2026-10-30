# async/event_loop.nim
## Event loop implementation for async terminal apps

import std/asyncdispatch
import std/tables
import std/options
import std/deques
import driver

export driver

type
  EventHandler* = proc(event: Event): Future[bool] {.gcsafe.}
  
  EventLoop* = ref object
    driver*: AsyncDriver
    handlers*: Table[EventKind, seq[EventHandler]]
    running*: bool
    eventQueue: Deque[Event]

proc newEventLoop*(driver: AsyncDriver): EventLoop =
  ## Create a new event loop
  result = EventLoop(
    driver: driver,
    handlers: initTable[EventKind, seq[EventHandler]](),
    running: false,
    eventQueue: initDeque[Event]()
  )

proc addHandler*(loop: EventLoop, kind: EventKind, handler: EventHandler) =
  ## Add an event handler
  if kind notin loop.handlers:
    loop.handlers[kind] = @[]
  loop.handlers[kind].add(handler)

proc removeHandler*(loop: EventLoop, kind: EventKind, handler: EventHandler) =
  ## Remove an event handler
  if kind in loop.handlers:
    let idx = loop.handlers[kind].find(handler)
    if idx >= 0:
      loop.handlers[kind].del(idx)

proc dispatchEvent*(loop: EventLoop, event: Event) {.async.} =
  ## Dispatch an event to registered handlers
  if event.kind in loop.handlers:
    for handler in loop.handlers[event.kind]:
      let handled = await handler(event)
      if handled:
        break

proc processEvents*(loop: EventLoop) {.async.} =
  ## Process all pending events
  while loop.eventQueue.len > 0:
    let event = loop.eventQueue.popFirst()
    await loop.dispatchEvent(event)

proc run*(loop: EventLoop) {.async.} =
  ## Run the event loop
  loop.running = true
  
  while loop.running:
    # Read next event from driver
    let eventOpt = await loop.driver.readEvent()
    
    if eventOpt.isSome:
      let event = eventOpt.get
      loop.eventQueue.addLast(event)
    
    # Process queued events
    await loop.processEvents()
    
    # Small delay to prevent busy waiting
    await sleepAsync(1)

proc stop*(loop: EventLoop) =
  ## Stop the event loop
  loop.running = false

proc postEvent*(loop: EventLoop, event: Event) =
  ## Post a custom event to the queue
  loop.eventQueue.addLast(event)