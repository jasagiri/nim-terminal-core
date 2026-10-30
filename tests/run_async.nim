## TC-A-8 の E テストが擬似端末の上で起こすアプリ。asyncdispatch の時計 (sleepAsync) と、ループバックの TCP の
## やりとりの結果を見せる。q で終わる。

import std/[asyncdispatch, asyncnet, nativesockets]
import nim_terminal_core
import nim_terminal_core/asyncloop

proc main(): int =
  let clock = newLabel("clock ?")
  let net = newLabel("net ?")
  let app = newApp(vbox(clock.widget, net.widget))
  let drive = driveAsync(app)
  proc ticks() {.async.} =
    await sleepAsync(150)
    clock.setText("clock 150ms")
  proc talk() {.async.} =
    let server = newAsyncSocket()
    server.setSockOpt(OptReuseAddr, true)
    server.bindAddr(Port(0), "127.0.0.1")
    server.listen()
    let port = server.getLocalAddr()[1]
    let client = newAsyncSocket()
    await client.connect("127.0.0.1", port)
    let peer = await server.accept()
    await client.send("hello\n")
    let line = await peer.recvLine()
    net.setText("net " & line)
    client.close()
    peer.close()
    server.close()
  asyncCheck ticks()
  asyncCheck talk()
  let bound = app.shortcuts.add("q", "quit", proc () = app.quit())
  doAssert bound.isOk
  let ran = app.run()
  drive.stop()
  if drive.problems.len > 0 or not ran.isOk: return 1
  0

quit main()
