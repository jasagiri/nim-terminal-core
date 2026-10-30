## TC-A-1・2・5: run を擬似端末の上で動かし、端末に書かれたバイトを vt (nim-terminal-io の端末の模型) で
## 読み戻す。端末のモード (代替画面・貼り付け・マウス) が入り、どの終わり方でも戻ることを確かめる。

import std/[unittest, posix, os, strutils, options, monotimes, times]
import nim_outcome
import nim_terminal_io/[tty, vt]
import libplatform

let build = currentSourcePath().parentDir.parentDir / "build"
let runApp = build / "run_app"
let launcher = build / "launcher"
let runAsync = build / "run_async"
doAssert fileExists(runApp) and fileExists(launcher), "nim test builds them first"

proc pump(master: cint, v: var Vt, until: proc(v: Vt): bool, ms = 5000): bool =
  ## master を読み続けて v に流し、until が真になれば true
  let deadline = getMonoTime() + initDuration(milliseconds = ms)
  var buf: array[4096, char]
  while getMonoTime() < deadline:
    if until(v): return true
    let ready = waitReadable([master], 50).get
    if ready[0]:
      let n = posix.read(master, addr buf[0], buf.len)
      if n <= 0: return until(v)
      var s = newString(n)
      copyMem(addr s[0], addr buf[0], n)
      v.feed(s)
  until(v)

proc send(master: cint, s: string) =
  doAssert posix.write(master, cstring(s), s.len) == s.len

proc shows(text: string): proc(v: Vt): bool =
  result = proc(v: Vt): bool = text in v.text

proc modesOn(v: Vt): bool = "1049" in v.modes and "2004" in v.modes and "1002" in v.modes and "1006" in v.modes
proc modesOff(v: Vt): bool = "1049" notin v.modes and "2004" notin v.modes and "1002" notin v.modes

proc finish(master: cint, v: var Vt, pid: Pid): ChildStatus =
  ## 子が終わるまで master を読み続けて v に流す (子は、端末を閉じるとき出力が読まれるまで待つ)
  while true:
    let st = waitChild(pid, wait = false).get
    if st.isSome: return st.get
    discard pump(master, v, proc(v: Vt): bool = false, 50)   # Why discard: 読むだけ

suite "run":
  test "TC-A-8 Given asyncdispatch work in an app When it runs Then timers and sockets of asyncdispatch progress in the app's loop":
    let p = spawnInPty(SpawnSpec(argv: @[runAsync]), 30, 4).get
    var v = newVt(30, 4)
    check pump(p.master, v, shows("clock 150ms"))
    check pump(p.master, v, shows("net hello"))
    p.master.send("q")
    check finish(p.master, v, p.pid) == ChildStatus(pid: p.pid, state: csExited, code: 0)   # problems は空
    check posix.close(p.master) == 0

  test "TC-A-1 Given an app run in a terminal When it starts and quits Then the terminal modes are on while running and all restored after, and TC-A-7 a watched fd is read":
    let p = spawnInPty(SpawnSpec(argv: @[runApp]), 40, 10).get
    var v = newVt(40, 10)
    check pump(p.master, v, shows("size 40x10"))
    check v.modesOn
    check "25" in v.modes                    # A-6: 入力欄にフォーカスがあるのでカーソルを出す
    check pump(p.master, v, shows("pipe ping"))   # A-7: 見張った fd
    p.master.send("ab")
    check pump(p.master, v, shows("echo ab"))
    p.master.send("\t\r")                     # Quit のボタンへ移って押す
    check finish(p.master, v, p.pid) == ChildStatus(pid: p.pid, state: csExited, code: 0)
    check v.modesOff and v.problems.len == 0
    check posix.close(p.master) == 0

  test "TC-A-2 Given a running app When the terminal is resized Then it lays out again at the new size and redraws all":
    let p = spawnInPty(SpawnSpec(argv: @[runApp]), 40, 10).get
    var v = newVt(40, 10)
    check pump(p.master, v, shows("size 40x10"))
    check resize(p.master, 50, 12).isOk
    var w = newVt(50, 12)                    # 描き直しは画面を消して全部を描くので、新しい模型で読める
    check pump(p.master, w, shows("size 50x12"))
    check w.row(3).startsWith("[ Quit ]")
    check signalProcess(p.pid, SIGTERM).isOk
    check finish(p.master, w, p.pid).state == csSignaled
    check posix.close(p.master) == 0

  test "TC-A-1 Given a running app When SIGTERM comes Then it restores the terminal and ends by that signal":
    let p = spawnInPty(SpawnSpec(argv: @[runApp]), 40, 10).get
    var v = newVt(40, 10)
    check pump(p.master, v, shows("size 40x10")) and v.modesOn
    check signalProcess(p.pid, SIGTERM).isOk
    check finish(p.master, v, p.pid) == ChildStatus(pid: p.pid, state: csSignaled, code: SIGTERM)
    check v.modesOff
    check posix.close(p.master) == 0

  test "TC-A-5 Given an app in the foreground group When Ctrl+Z comes Then it restores the terminal and stops, and on continuing re-enters and redraws":
    let p = spawnInPty(SpawnSpec(argv: @[launcher, runApp]), 40, 10).get
    var v = newVt(40, 10)
    check pump(p.master, v, shows("size 40x10")) and v.modesOn
    p.master.send("\x1a")
    check pump(p.master, v, shows("STOPPED"))
    check v.modesOff
    var again = newVt(40, 10)
    p.master.send("c\n")
    check pump(p.master, again, shows("size 40x10")) and again.modesOn
    p.master.send("\t\r")
    check pump(p.master, again, shows("EXIT 0")) and again.modesOff
    check finish(p.master, again, p.pid).state == csExited
    check posix.close(p.master) == 0
