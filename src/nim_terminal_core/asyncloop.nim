## アプリのループで std/asyncdispatch を回す (A-8)。asyncdispatch の上の部品 (9P のサーバ、HTTP のクライアント、MCP) を
## 端末の UI と同じスレッドで動かすため。nim_terminal_core は既定ではこの module を import しない (asyncdispatch を
## 引き込まない)。
## Why not asyncdispatch の runForever を回して UI を載せる: UI のループは /dev/tty を select で待つ (macOS の poll は
## /dev/tty を受けない)。asyncdispatch のセレクタの fd を UI のループの見張りに足すほうが、片方の作りを変えずに済む。

import std/[asyncdispatch, selectors]
import ./app

type
  AsyncDrive* = ref object
    app: App
    fd: cint
    timer: Timer
    running: bool
    problems*: seq[string]   ## poll の中で起きた誤り (asyncdispatch の手続きが投げた例外の文面)

const AsyncTickMs* = 10
  ## asyncdispatch の時計 (sleepAsync・期限) は fd を持たないので、待っている仕事がある間はこの間隔でも回す

proc pollOnce(d: AsyncDrive) {.raises: [].} =
  ## 待たずに 1 回回す。待っている仕事が無ければ何もしない (poll は仕事が無いと ValueError を投げる)。
  try:
    if hasPendingOperations(): poll(0)
  except CatchableError as e:
    d.problems.add e.msg
  except Defect as e:
    raise e                # 不具合は止める (握らない)
  except Exception as e:   # Why: asyncdispatch の poll は raises の注釈を持たず、callback の例外をそのまま通す
    d.problems.add e.msg

proc driveAsync*(app: App): AsyncDrive {.raises: [].} =
  ## A-8: asyncdispatch のセレクタ (Linux は epoll、macOS は kqueue) の fd を見張り、読めるたびに poll(0) で回す。
  ## 待っている仕事がある間は AsyncTickMs ごとにも回す (時計の仕事のため)。
  let d = AsyncDrive(app: app, running: true)
  try:
    d.fd = cint(getGlobalDispatcher().getIoHandler().getFd())
  except Defect as e:
    raise e
  except Exception as e:   # Why: getGlobalDispatcher は raises の注釈を持たない (セレクタを作れないときに投げる)
    d.problems.add "cannot open the async dispatcher: " & e.msg
    d.running = false
    return d
  app.watchFd(d.fd, proc () {.closure, raises: [].} = d.pollOnce())
  d.timer = app.every(AsyncTickMs, proc () {.closure, raises: [].} = d.pollOnce())
  d

proc stop*(d: AsyncDrive) {.raises: [].} =
  ## 見張りとタイマーを外す。asyncdispatch の仕事は残る (ループはもう回さない)。
  if not d.running: return
  d.running = false
  d.app.unwatchFd(d.fd)
  d.timer.cancel()
