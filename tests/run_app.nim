## TC-A-* の E テストが擬似端末の上で起こすアプリ。大きさを見せ、打った文字を写し、Quit で終わる。
## A-7: 自分で書いた pipe を見張り、読んだ文字を見せる。

import std/posix
import nim_terminal_core

proc main(): int =
  let shownSize = newLabel("size ?")
  let input = newTextInput(placeholder = "type")
  let echoed = newLabel("echo")
  let quitButton = newButton("Quit")
  let piped = newLabel("pipe ?")
  let app = newApp(vbox(shownSize.widget, input.widget, echoed.widget, quitButton.widget, piped.widget))
  var fds: array[0..1, cint]
  doAssert pipe(fds) == 0
  let (readEnd, writeEnd) = (fds[0], fds[1])
  app.watchFd(readEnd, proc() =
    var buf: array[64, char]
    let n = posix.read(readEnd, addr buf[0], buf.len)
    if n > 0:
      var s = newString(n)
      copyMem(addr s[0], addr buf[0], n)
      piped.setText("pipe " & s)
    else: app.unwatchFd(readEnd))
  var written = false
  discard app.every(100, proc() =
    if not written:
      written = true
      discard posix.write(writeEnd, cstring("ping"), 4))   # Why discard: 届かなければ試験が "pipe ping" を見ない
  quitButton.onClick = proc() = app.quit()
  input.onChange = proc(t: string) = echoed.setText("echo " & t)
  discard app.every(30, proc() = shownSize.setText("size " & $app.size.width & "x" & $app.size.height))
  let r = app.run()
  if r.isFailure:
    stderr.writeLine "run_app: " & r.error
    return 2
  if r.get.signal != 0:
    # 端末は run が戻した。そのシグナルで終わり直す (既定の扱いは run の stopWatching が戻した)
    discard kill(getpid(), r.get.signal)   # Why discard: 届けば戻らない。戻れば下で終わる
    exitnow(128 + r.get.signal)
  0

quit(main())
