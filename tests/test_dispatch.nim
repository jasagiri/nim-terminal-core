## TC-E-*: キー・マウス・貼り付けの振り分け、フォーカス、層。TC-A-*: 描画、カーソル、タイマー。

import std/[unittest, unicode, options, strutils, monotimes, times]
import nim_terminal_core

type Probe = ref object
  widget: Widget
  log: ref seq[string]
  takes: set[EventKind]

proc probe(name: string, log: ref seq[string], focusable = false, takes: set[EventKind] = {},
           constraint = fill()): Probe =
  let p = Probe(log: log, takes: takes)
  p.widget = newWidget(name, focusable = focusable).sized(constraint)
  p.widget.behavior.handle = proc(e: Event): bool =
    var s = name & " " & $e.kind
    if e.isMouse: s.add " " & $e.x & "," & $e.y
    if e.kind == evKey and e.key.kind == kRune: s.add " " & $e.key.rune
    if e.kind == evPaste: s.add " " & e.text
    log[].add s
    e.kind in p.takes
  p

proc key(c: char, mods: set[KeyMod] = {}): KeyEvent = KeyEvent(kind: kRune, rune: Rune(ord(c)), mods: mods)
proc key(k: KeyKind, mods: set[KeyMod] = {}): KeyEvent = KeyEvent(kind: k, mods: mods)
proc mouse(a: MouseAction, x, y: int, b = mbLeft): KeyEvent =
  KeyEvent(kind: kMouse, mouse: MouseInfo(action: a, button: b, x: x, y: y))

proc click(app: App, x, y: int, at: int64) =
  app.feed(mouse(maPress, x, y), at)
  app.feed(mouse(maRelease, x, y), at)

proc keysOnly(log: seq[string]): seq[string] =
  for l in log:
    if " evFocus" notin l: result.add l

suite "dispatch":
  test "TC-E-1 Given a focused widget inside boxes When a key comes Then it goes to the focused widget first and bubbles until handled":
    let log = new seq[string]
    let leafP = probe("leaf", log, focusable = true)
    let mid = probe("mid", log, takes = {evKey})
    mid.widget.arrangement = arVertical
    mid.widget.add leafP.widget
    let root = probe("root", log)
    root.widget.arrangement = arVertical
    root.widget.add mid.widget
    let app = newApp(root.widget)
    app.resize(10, 5)
    discard app.draw()
    check app.focused == leafP.widget
    log[].setLen(0)
    app.feed(key('a'), 0)
    check log[] == @["leaf evKey a", "mid evKey a"]

  test "TC-E-2 Given a key no widget handles When fed Then shortcuts run, Tab moves focus, and Ctrl+C quits":
    let log = new seq[string]
    let a = probe("a", log, focusable = true)
    let b = probe("b", log, focusable = true)
    let app = newApp(vbox(a.widget, b.widget))
    app.resize(10, 4)
    var saved = 0
    check app.shortcuts.add("ctrl+s", "save", proc() = inc saved).isOk
    discard app.draw()
    app.feed(key('s', {mCtrl}), 0)
    check saved == 1
    app.feed(key(kTab), 0)
    check app.focused == b.widget
    check app.running
    app.feed(key('c', {mCtrl}), 0)
    check not app.running

  test "TC-E-2 Given a widget that handles a key bound as a shortcut Then the widget wins":
    let log = new seq[string]
    let a = probe("a", log, focusable = true, takes = {evKey})
    let app = newApp(vbox(a.widget))
    app.resize(10, 4)
    var ran = false
    check app.shortcuts.add("q", "quit", proc() = ran = true).isOk
    app.feed(key('q'), 0)
    check not ran

  test "TC-E-3 Given focusables, one disabled and one hidden When Tab and Shift+Tab are pressed Then focus moves in tree order, skips them, wraps, and tells each widget":
    let log = new seq[string]
    let a = probe("a", log, focusable = true)
    let b = probe("b", log, focusable = true)
    let c = probe("c", log, focusable = true)
    let d = probe("d", log, focusable = true)
    b.widget.enabled = false
    let hidden = vbox(c.widget)
    hidden.visible = false
    let app = newApp(vbox(a.widget, hbox(b.widget, hidden), d.widget))
    app.resize(10, 6)
    discard app.draw()
    check app.focused == a.widget
    app.feed(key(kTab), 0)
    check app.focused == d.widget
    app.feed(key(kTab), 0)
    check app.focused == a.widget
    app.feed(key(kTab, {mShift}), 0)
    check app.focused == d.widget
    check "a evFocusOut" in log[] and "d evFocusIn" in log[]
    check not app.focus(b.widget) and not app.focus(c.widget)

  test "TC-E-4 Given nested widgets When the mouse is pressed Then the deepest one under it gets the press in its own coordinates, and the nearest focusable takes focus":
    let log = new seq[string]
    let inner = probe("inner", log, constraint = fixed(2))
    let field = probe("field", log, focusable = true)
    field.widget.arrangement = arVertical
    field.widget.add newWidget().sized(fixed(1))
    field.widget.add inner.widget
    let other = probe("other", log, focusable = true)
    let app = newApp(vbox(other.widget, field.widget))
    app.resize(10, 10)
    discard app.draw()
    check app.focused == other.widget
    log[].setLen(0)
    app.feed(mouse(maPress, 3, 6), 0)    # field は y=5 から、inner は y=6 から
    check app.focused == field.widget
    check log[].keysOnly == @["inner evPress 3,0", "field evPress 3,1"]

  test "TC-E-4 Given overlapping children in a stack Then the later one is hit":
    let log = new seq[string]
    let under = probe("under", log)
    let over = probe("over", log, takes = {evPress})
    let app = newApp(stack(under.widget, over.widget))
    app.resize(5, 5)
    discard app.draw()
    app.feed(mouse(maPress, 1, 1), 0)
    check log[] == @["over evPress 1,1"]

  test "TC-E-5 Given a press on a widget When dragged and released outside it Then it still gets the drag and the release, in its coordinates, and no click":
    let log = new seq[string]
    let a = probe("a", log, constraint = fixed(2))
    let b = probe("b", log)
    let app = newApp(vbox(a.widget, b.widget))
    app.resize(10, 6)
    discard app.draw()
    app.feed(mouse(maPress, 1, 1), 0)
    app.feed(mouse(maDrag, 2, 4), 0)
    app.feed(mouse(maRelease, 2, 4), 0)
    check log[] == @["a evPress 1,1", "a evDrag 2,4", "a evRelease 2,4"]

  test "TC-E-6 Given clicks on the same cell When the second comes within 400 ms Then a double click follows the second click; later or elsewhere it does not":
    let log = new seq[string]
    let a = probe("a", log)
    let app = newApp(vbox(a.widget))
    app.resize(10, 3)
    discard app.draw()
    app.click(1, 1, 1000)
    app.click(1, 1, 1300)
    var kinds: seq[string]
    for l in log[]:
      if "Click" in l: kinds.add l
    check kinds == @["a evClick 1,1", "a evClick 1,1", "a evDoubleClick 1,1"]
    log[].setLen(0)
    app.click(1, 1, 2000)
    app.click(1, 1, 2500)    # 遅すぎる
    app.click(2, 1, 2600)    # 別のセル
    var doubles = 0
    for l in log[]:
      if "evDoubleClick" in l: inc doubles
    check doubles == 0

  test "TC-E-7 Given a wheel over a widget Then it goes to the widget under the pointer and bubbles":
    let log = new seq[string]
    let a = probe("a", log, focusable = true)
    let b = probe("b", log)
    let box = probe("box", log, takes = {evWheel})
    box.widget.arrangement = arVertical
    box.widget.add b.widget
    let app = newApp(vbox(a.widget, box.widget))
    app.resize(10, 4)
    discard app.draw()
    app.feed(mouse(maWheelDown, 0, 3, mbNone), 0)
    check log[].keysOnly == @["b evWheel 0,1", "box evWheel 0,1"]
    check app.focused == a.widget

  test "TC-E-8 Given a modal layer When keys and mouse come Then keys stay in it, the mouse outside is dropped, and closing it brings focus back":
    let log = new seq[string]
    let a = probe("a", log, focusable = true)
    let b = probe("b", log, focusable = true)
    let app = newApp(vbox(a.widget, b.widget))
    app.resize(20, 10)
    discard app.draw()
    app.feed(key(kTab), 0)
    check app.focused == b.widget
    let ok = probe("ok", log, focusable = true)
    let cancel = probe("cancel", log, focusable = true)
    let dialog = hbox(ok.widget, cancel.widget)
    app.openLayer(dialog, centered(10, 2))
    discard app.draw()
    check app.focused == ok.widget
    app.feed(key(kTab), 0)
    app.feed(key(kTab), 0)
    check app.focused == ok.widget            # 層の中で回る
    log[].setLen(0)
    app.feed(mouse(maPress, 0, 0), 0)          # 層の外
    check log[].len == 0 and app.focused == ok.widget
    app.closeLayer(dialog)
    check app.focused == b.widget

  test "TC-E-8 Given a popup layer When pressed outside Then it closes and the press goes nowhere":
    let log = new seq[string]
    let a = probe("a", log, focusable = true)
    let app = newApp(vbox(a.widget))
    app.resize(20, 10)
    let item = probe("item", log, focusable = true)
    app.openLayer(vbox(item.widget), at(2, 2, 5, 3), lmPopup)
    discard app.draw()
    log[].setLen(0)
    app.feed(mouse(maPress, 15, 8), 0)
    check not app.isOpen(item.widget.parent)
    check log[].keysOnly.len == 0

  test "TC-E-9 Given a disabled widget When clicked Then neither it nor its parent receives the event":
    let log = new seq[string]
    let a = probe("a", log, focusable = true)
    a.widget.enabled = false
    let box = probe("box", log)
    box.widget.arrangement = arVertical
    box.widget.add a.widget
    let app = newApp(box.widget)
    app.resize(5, 5)
    discard app.draw()
    app.click(1, 1, 0)
    check log[].len == 0 and app.focused.isNil

  test "TC-E-10 Given a paste When fed Then the focused widget gets the text and it bubbles, without shortcuts":
    let log = new seq[string]
    let a = probe("a", log, focusable = true)
    let app = newApp(vbox(a.widget))
    app.resize(5, 2)
    var ran = false
    check app.shortcuts.add("x", "x", proc() = ran = true).isOk
    app.feed(KeyEvent(kind: kPaste, text: "x"), 0)
    check "a evPaste x" in log[] and not ran

suite "app":
  test "TC-A-3 Given a tree and a layer When drawn Then the root is drawn first and the layer on top":
    let back = newWidget(behavior = Behavior(render: proc(c: Canvas, t: Theme, f: bool) =
      for y in 0 ..< c.height: discard c.put(0, y, "..........")))
    let front = newWidget(behavior = Behavior(render: proc(c: Canvas, t: Theme, f: bool) =
      discard c.put(0, 0, "XYZ")))
    let app = newApp(back)
    app.resize(10, 3)
    app.openLayer(front, at(2, 1, 3, 1))
    let s = app.draw()
    var row1 = ""
    for x in 0 ..< 10: row1.add s.screen.cellText(x, 1)
    check row1 == "..XYZ....."

  test "TC-A-9 Given an app When it draws Then it counts the frames and keeps how long the last draw took":
    let slow = newWidget(behavior = Behavior(render: proc(c: Canvas, t: Theme, f: bool) =
      let until = getMonoTime() + initDuration(milliseconds = 3)
      while getMonoTime() < until: discard))   # Why discard: 描くのに 3 ms かかるウィジェット
    let app = newApp(slow)
    app.resize(4, 1)
    check app.frames == 0 and app.lastDrawMs == 0
    discard app.draw()
    discard app.draw()
    check app.frames == 2
    check app.lastDrawMs >= 3 and app.lastDrawMs < 1000

  test "TC-A-6 Given widgets that set the cursor When drawn Then only the focused widget's cursor is kept, and none when nothing is focused":
    proc cursorAt(x: int, focusable: bool): Widget =
      newWidget(focusable = focusable, behavior = Behavior(render: proc(c: Canvas, t: Theme, f: bool) =
        c.setCursor(x, 0)))
    let a = cursorAt(1, true)
    let b = cursorAt(2, false)
    let app = newApp(vbox(a, b))
    app.resize(5, 2)
    check app.draw().cursor == some((x: 1, y: 0))
    a.focusable = false
    check app.draw().cursor.isNone

  test "TC-A-4 Given timers When time passes Then each runs once per due time, without catching up, and a cancelled one stops":
    let app = newApp(newWidget())
    var a, b = 0
    discard app.every(100, 0, proc() = inc a)
    let t = app.every(250, 0, proc() = inc b)
    app.runDue(50)
    check a == 0
    app.runDue(100)
    app.runDue(150)
    check a == 1
    app.runDue(1000)          # 遅れても 1 度
    check a == 2 and b == 1
    t.cancel()
    app.runDue(5000)
    check a == 3 and b == 1
