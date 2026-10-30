# async/driver.nim
## Asynchronous terminal driver abstraction

import std/asyncdispatch
import std/options
import ../raw
import ../input
import ../output
import ../mouse
import ../private/common

type
  DriverKind* = enum
    dkLinux     # Linux/macOS terminals
    dkWindows   # Windows terminals
    dkHeadless  # Testing without terminal

  AsyncDriver* = ref object of RootObj
    ## Base async driver interface
    case kind*: DriverKind
    of dkLinux, dkWindows:
      inputFd: AsyncFD
    of dkHeadless:
      discard

  EventKind* = enum
    ekKey
    ekMouse
    ekResize
    ekCustom

  Event* = object
    ## Generic event type
    case kind*: EventKind
    of ekKey:
      key*: KeyEvent
    of ekMouse:
      mouse*: MouseEvent
    of ekResize:
      width*, height*: int
    of ekCustom:
      data*: pointer

proc newAsyncDriver*(kind: DriverKind = dkLinux): AsyncDriver =
  ## Create a new async driver
  result = AsyncDriver(kind: kind)
  case kind
  of dkLinux, dkWindows:
    result.inputFd = stdin.getFileHandle().AsyncFD
    register(result.inputFd)
  of dkHeadless:
    discard

proc readEvent*(driver: AsyncDriver): Future[Option[Event]] {.async.} =
  ## Read next event asynchronously
  case driver.kind
  of dkLinux, dkWindows:
    # Create a future that completes when data is available
    var fut = newFuture[void]("readEvent")
    proc cb(fd: AsyncFD): bool =
      fut.complete()
      return true  # Remove callback after first trigger
    
    addRead(driver.inputFd, cb)
    await fut
    
    # Read input event using the input module
    let event = readInput()
    case event.kind
    of EvKey:
      return some(Event(kind: ekKey, key: event.key))
    of EvMouse:
      return some(Event(kind: ekMouse, mouse: event.mouse))
    of EvResize:
      return some(Event(kind: ekResize, width: event.resize.width, height: event.resize.height))
    else:
      return none(Event)
    
  of dkHeadless:
    # For testing - yield control and return none
    await sleepAsync(1)
    return none(Event)

proc write*(driver: AsyncDriver, x, y: int, text: string, 
           style: Style = defaultStyle) {.async.} =
  ## Write text at position asynchronously
  # For now, use synchronous write (fast enough)
  # Could buffer and batch writes in the future
  setCursor(x, y)
  setStyle(style)
  stdout.write(text)
  stdout.flushFile()

proc clear*(driver: AsyncDriver) {.async.} =
  ## Clear the screen
  clearScreen()

proc flush*(driver: AsyncDriver) {.async.} =
  ## Flush any pending output
  stdout.flushFile()