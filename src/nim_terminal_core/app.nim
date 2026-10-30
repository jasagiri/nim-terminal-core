## アプリ: ウィジェットの木と、その上に開く層 (ダイアログ・メニュー)、フォーカス、事象の振り分け、描画、
## タイマー。`feed`・`draw`・`runDue` は I/O を持たず、`run` が端末とつなぐ。規則は ADR-TC-0001 の E-1〜E-10、
## A-1〜A-6。

import std/[options, monotimes, posix, unicode]
import nim_outcome
import nim_unicode_width
import nim_terminal_io/[tty, signals, keys, screen]
import ./[geometry, canvas, theme, event, widget, layout, shortcuts]

export MouseReporting

type
  LayerMode* = enum
    lmModal   ## 外のマウスは捨て、キーはこの層だけに届く
    lmPopup   ## 外を押すと閉じる (その押しは下に渡さない)

  Layer = object
    widget: Widget
    placeAt: proc(screen: Size): Rect {.closure, raises: [].}
    mode: LayerMode
    savedFocus: Widget

  Timer* = ref object
    interval: int
    next: int64
    action: proc() {.closure, raises: [].}
    active: bool

  App* = ref object
    root*: Widget
    theme*: Theme
    shortcuts*: Shortcuts
    widthOptions*: WidthOptions
    mouse*: MouseReporting      ## run が入れるマウスの報告 (既定はドラッグまで)
    quitOnCtrlC*: bool          ## 誰も扱わなかった Ctrl+C で終わる (既定は真)
    layers: seq[Layer]
    focus: Widget
    capture: Widget
    lastClick: tuple[target: Widget, x, y: int, at: int64]
    width, height: int
    running: bool
    suspendWanted: bool
    timers: seq[Timer]

  Ending* = object
    signal*: cint   ## SIGTERM などで終わったときの番号。quit で終わったときは 0

const DoubleClickMs* = 400
const EscWaitMs = 50

proc newApp*(root: Widget, theme = defaultTheme()): App {.raises: [].} =
  App(root: root, theme: theme, shortcuts: newShortcuts(), mouse: mrDrag, quitOnCtrlC: true, running: true)

proc size*(app: App): Size {.raises: [].} = size(app.width, app.height)
proc focused*(app: App): Widget {.raises: [].} = app.focus   ## 入力を受けているウィジェット。無ければ nil
proc running*(app: App): bool {.raises: [].} = app.running
proc quit*(app: App) {.raises: [].} = app.running = false

proc layerRoot(app: App): Widget =
  if app.layers.len > 0: app.layers[^1].widget else: app.root

proc usable(w: Widget): bool =
  ## E-9: 自分と祖先が全部、見えて有効
  var p = w
  while not p.isNil:
    if not p.visible or not p.enabled: return false
    p = p.parent
  true

proc focusables(w: Widget, into: var seq[Widget]) =
  if not w.visible or not w.enabled: return
  if w.focusable: into.add w
  for c in w.children: focusables(c, into)

proc handleAt(w: Widget, e: Event): bool =
  if w.behavior.handle.isNil: false else: w.behavior.handle(e)

proc setFocus(app: App, w: Widget) =
  if app.focus == w: return
  let old = app.focus
  app.focus = w
  if not old.isNil: discard old.handleAt(Event(kind: evFocusOut))   # Why discard: 知らせるだけ。扱ったかは問わない
  if not w.isNil: discard w.handleAt(Event(kind: evFocusIn))

proc focus*(app: App, w: Widget): bool {.raises: [].} =
  ## w に入力を向ける。w が今の一番上の層の中の、見えて有効で受けられるウィジェットでなければ false。
  if w.isNil or not w.focusable or not w.usable or not app.layerRoot.isAncestorOf(w): return false
  app.setFocus(w)
  true

proc moveFocus(app: App, by: int) =
  ## E-3: 一番上の層の受けられるウィジェットを前順に並べ、次 (前) へ。端で回る
  var order: seq[Widget]
  focusables(app.layerRoot, order)
  if order.len == 0: return
  var at = order.find(app.focus)
  if at < 0: at = (if by > 0: -1 else: 0)
  app.setFocus(order[(at + by + order.len) mod order.len])

proc focusNext*(app: App) {.raises: [].} = app.moveFocus(1)
proc focusPrevious*(app: App) {.raises: [].} = app.moveFocus(-1)

proc ensureFocus(app: App) =
  ## フォーカスが無いか、層の外か、受けられなくなっていたら、層の最初のものへ
  if app.focus.isNil or not app.focus.focusable or not app.focus.usable or not app.layerRoot.isAncestorOf(app.focus):
    var order: seq[Widget]
    focusables(app.layerRoot, order)
    app.setFocus(if order.len > 0: order[0] else: nil)

proc openLayer*(app: App, w: Widget, placeAt: proc(screen: Size): Rect {.closure, raises: [].},
                mode = lmModal) {.raises: [].} =
  ## w を今の画面の上に開く。置き場所は画面の大きさから placeAt が決める (大きさが変わると決め直す)。
  ## 開く前のフォーカスを覚え、層の最初の受けられるウィジェットにフォーカスを移す。
  app.layers.add Layer(widget: w, placeAt: placeAt, mode: mode, savedFocus: app.focus)
  app.capture = nil
  var order: seq[Widget]
  focusables(w, order)
  app.setFocus(if order.len > 0: order[0] else: nil)

proc closeLayer*(app: App, w: Widget) {.raises: [].} =
  ## E-8: 層を閉じ、開く前のフォーカスに戻す (戻せなければ下の層の最初のもの)。
  for i, l in app.layers:
    if l.widget == w:
      let saved = l.savedFocus
      app.layers.delete(i)
      if app.focus.isNil or w.isAncestorOf(app.focus): app.focus = nil
      app.capture = nil
      if not saved.isNil and saved.usable and app.layerRoot.isAncestorOf(saved): app.setFocus(saved)
      else: app.ensureFocus()
      return

proc isOpen*(app: App, w: Widget): bool {.raises: [].} =
  for l in app.layers:
    if l.widget == w: return true

proc centered*(width, height: int): proc(screen: Size): Rect {.closure, raises: [].} =
  ## 画面の中央に width × height (画面より大きければ画面の大きさ) で置く。
  result = proc(screen: Size): Rect =
    let w = min(width, screen.width)
    let h = min(height, screen.height)
    rect((screen.width - w) div 2, (screen.height - h) div 2, w, h)

proc at*(x, y, width, height: int): proc(screen: Size): Rect {.closure, raises: [].} =
  ## (x, y) から width × height で置く。画面からはみ出すなら、内へずらす。
  result = proc(screen: Size): Rect =
    let w = min(width, screen.width)
    let h = min(height, screen.height)
    rect(max(0, min(x, screen.width - w)), max(0, min(y, screen.height - h)), w, h)

proc resize*(app: App, width, height: int) {.raises: [].} =
  app.width = max(width, 0)
  app.height = max(height, 0)

proc arrangeAll(app: App) =
  layout(app.root, rect(0, 0, app.width, app.height), app.widthOptions)
  for l in app.layers: layout(l.widget, l.placeAt(app.size), app.widthOptions)

proc renderTree(app: App, s: Surface, w: Widget, cursor: var Option[tuple[x, y: int]]) =
  if not w.visible or w.shown.isEmpty: return
  if not w.behavior.render.isNil:
    let isFocus = w == app.focus
    s.cursor = none(tuple[x, y: int])
    w.behavior.render(s.within(w.rect, w.shown), app.theme, isFocus)
    if isFocus: cursor = s.cursor     # A-6: 端末のカーソルは、フォーカスのウィジェットが置いた所だけ
  for c in w.children: app.renderTree(s, c, cursor)

proc draw*(app: App): Surface {.raises: [].} =
  ## A-3: 割り付けてから、根、層の順に描く。端末のカーソルは、フォーカスのウィジェットが置いた所。
  app.arrangeAll()
  app.ensureFocus()
  let s = newSurface(app.width, app.height, app.widthOptions)
  var cursor = none(tuple[x, y: int])
  app.renderTree(s, app.root, cursor)
  for l in app.layers: app.renderTree(s, l.widget, cursor)
  s.cursor = cursor
  s

proc hit(w: Widget, x, y: int): Widget =
  ## 点 (x, y) の一番深いウィジェット。後の子が上。無効のウィジェットに当たれば nil (届けない。E-9)
  if not w.visible or not w.shown.contains(x, y): return nil
  if not w.enabled: return nil
  for i in countdown(w.children.high, 0):
    let c = w.children[i]
    if c.visible and c.shown.contains(x, y): return hit(c, x, y)
  w

proc localized(e: Event, w: Widget): Event =
  result = e
  if e.isMouse:
    result.x = e.screenX - w.rect.x
    result.y = e.screenY - w.rect.y

proc bubble(app: App, start: Widget, e: Event, top: Widget): bool =
  ## E-1: start から top まで親へ渡し、扱われたら止める
  var w = start
  while not w.isNil:
    if w.enabled and w.handleAt(e.localized(w)): return true
    if w == top: break
    w = w.parent
  false

proc focusTarget(w: Widget): Widget =
  var p = w
  while not p.isNil:
    if p.focusable: return p
    p = p.parent

proc layerAt(app: App, x, y: int): tuple[found: bool, index: int] =
  for i in countdown(app.layers.high, 0):
    if app.layers[i].widget.shown.contains(x, y): return (true, i)
  (false, -1)

proc feedMouse(app: App, k: KeyEvent, nowMs: int64) =
  let m = k.mouse
  var e = Event(screenX: m.x, screenY: m.y, button: m.button, mods: k.mods)
  # E-5: 押したウィジェットが、ドラッグと離すを受ける
  if m.action in {maDrag, maRelease} and not app.capture.isNil:
    let target = app.capture
    if m.action == maDrag:
      e.kind = evDrag
      discard app.bubble(target, e, target)   # Why discard: 押したウィジェットだけに届ける
      return
    app.capture = nil
    e.kind = evRelease
    discard app.bubble(target, e, target)     # Why discard: 同上
    if target.usable and target.shown.contains(m.x, m.y):   # E-6
      discard app.bubble(target, Event(kind: evClick, screenX: m.x, screenY: m.y, button: m.button, mods: k.mods),
                         app.layerRoot)       # Why discard: 誰も扱わなくてよい
      let last = app.lastClick
      if last.target == target and last.x == m.x and last.y == m.y and nowMs - last.at <= DoubleClickMs:
        discard app.bubble(target, Event(kind: evDoubleClick, screenX: m.x, screenY: m.y, button: m.button,
                                         mods: k.mods), app.layerRoot)   # Why discard: 同上
        app.lastClick = (nil, 0, 0, 0'i64)
      else:
        app.lastClick = (target, m.x, m.y, nowMs)
    return
  # 層: E-8
  let (inLayer, li) = app.layerAt(m.x, m.y)
  var top = app.root
  if app.layers.len > 0:
    if inLayer and li == app.layers.high: top = app.layers[li].widget
    else:
      let l = app.layers[^1]
      if l.mode == lmPopup and m.action == maPress: app.closeLayer(l.widget)
      return
  let target = hit(top, m.x, m.y)
  if target.isNil: return
  case m.action
  of maPress:
    e.kind = evPress
    app.capture = target
    let f = target.focusTarget
    if not f.isNil: app.setFocus(f)                     # E-4
    discard app.bubble(target, e, top)                  # Why discard: 誰も扱わなくてよい
  of maMove:
    e.kind = evMove
    discard app.bubble(target, e, top)                  # Why discard: 同上
  of maWheelUp, maWheelDown, maWheelLeft, maWheelRight: # E-7
    e.kind = evWheel
    e.wheel = m.action
    discard app.bubble(target, e, top)                  # Why discard: 同上
  of maDrag, maRelease: discard                         # 押していないドラッグと離す (端末を後から入れたとき)

proc feed*(app: App, k: KeyEvent, nowMs: int64) {.raises: [].} =
  ## 端末から読んだ 1 つの事象を振り分ける。nowMs は単調な時計のミリ秒 (ダブルクリックの判定に使う)。
  ## E-1、E-2、E-10: キーと貼り付けは、フォーカスから層の根へ渡し、誰も扱わなければショートカット、
  ## Tab・Shift+Tab のフォーカスの移動、Ctrl+C (終わる)・Ctrl+Z (止める) の順。
  app.ensureFocus()
  if k.kind == kMouse:
    app.feedMouse(k, nowMs)
    return
  let e = if k.kind == kPaste: Event(kind: evPaste, text: k.text) else: Event(kind: evKey, key: k)
  let start = if app.focus.isNil: app.layerRoot else: app.focus
  if app.bubble(start, e, app.layerRoot): return
  if k.kind == kPaste: return
  if app.shortcuts.handle(k): return
  if k.kind == kTab and k.mods == {}: app.focusNext()
  elif k.kind == kTab and k.mods == {mShift}: app.focusPrevious()
  elif k.kind == kRune and k.mods == {mCtrl} and k.rune == Rune('c') and app.quitOnCtrlC: app.quit()
  elif k.kind == kRune and k.mods == {mCtrl} and k.rune == Rune('z'): app.suspendWanted = true

proc every*(app: App, intervalMs: int, startMs: int64, action: proc() {.closure, raises: [].}): Timer {.raises: [].} =
  ## A-4: startMs (単調な時計のミリ秒) から intervalMs ごとに action を動かす。
  result = Timer(interval: max(intervalMs, 1), next: startMs + max(intervalMs, 1), action: action, active: true)
  app.timers.add result

proc cancel*(t: Timer) {.raises: [].} = t.active = false

proc runDue*(app: App, nowMs: int64) {.raises: [].} =
  ## A-4: 時の来たタイマーを動かす。遅れた分を取り返して何度も動かすことはしない。
  var i = 0
  while i < app.timers.len:
    let t = app.timers[i]
    if not t.active:
      app.timers.delete(i)
      continue
    if t.next <= nowMs:
      t.next = nowMs + t.interval
      t.action()
    inc i

proc nextDue(app: App, nowMs: int64): int =
  result = -1
  for t in app.timers:
    if t.active:
      let wait = int(max(t.next - nowMs, 0))
      if result < 0 or wait < result: result = wait

proc nowMs*(): int64 {.raises: [].} = getMonoTime().ticks div 1_000_000

proc every*(app: App, intervalMs: int, action: proc() {.closure, raises: [].}): Timer {.raises: [].} =
  ## A-4: 今から intervalMs ごとに action を動かす。
  app.every(intervalMs, nowMs(), action)

proc enter(app: App, t: Tty): Outcome[void] =
  ?t.enterRaw()
  ?t.setAltScreen(true)
  ?t.setBracketedPaste(true)
  ?t.setCursorVisible(false)
  ?t.setMouseReporting(app.mouse)
  let (w, h) = ?t.size()
  app.resize(w, h)
  t.write("\e[2J")

proc frame(app: App, t: Tty, shown: var Screen, cursorOn: var bool): Outcome[void] =
  let s = app.draw()
  var bytes = render(shown, s.screen)
  shown = s.screen
  if s.cursor.isSome: bytes.add moveTo(s.cursor.get.x, s.cursor.get.y)
  if bytes.len > 0: ?t.write(bytes)
  if s.cursor.isSome != cursorOn:
    cursorOn = s.cursor.isSome
    ?t.setCursorVisible(cursorOn)   # tty が覚え、restore が戻す (TIO T-4)
  success()

proc loop(app: App, t: Tty, watch: SignalWatch): Outcome[Ending] =
  var shown = newScreen(app.width, app.height)
  var cursorOn = false
  var keyRest = ""
  while app.running:
    ?app.frame(t, shown, cursorOn)
    let due = app.nextDue(nowMs())
    let wait = if keyRest.len > 0: (if due < 0: EscWaitMs else: min(due, EscWaitMs)) else: due
    let ready = ?waitReadable([t.fd, watch.fd], wait)
    var events: seq[KeyEvent]
    if not ready[0] and not ready[1] and keyRest.len > 0:
      events = flushPending(keyRest)              # 時間切れ: 単独の Esc (TIO K-8)
      keyRest = ""
    if ready[0]:
      let d = decode(keyRest & ?t.readAvailable())
      events.add d.events
      keyRest = d.rest
    for e in events:
      app.feed(e, nowMs())
      if app.suspendWanted:                       # A-5
        app.suspendWanted = false
        ?t.restore()
        ?watch.suspendSelf()
        ?app.enter(t)
        shown = newScreen(app.width, app.height)
        cursorOn = false
    if ready[1]:
      for sig in ?watch.takeSignals():
        if sig == SIGWINCH:                       # A-2
          let (w, h) = ?t.size()
          app.resize(w, h)
          shown = newScreen(w, h)
          ?t.write("\e[2J")
        elif sig == SIGTSTP:
          ?t.restore()
          ?watch.suspendSelf()
          ?app.enter(t)
          shown = newScreen(app.width, app.height)
          cursorOn = false
        else:
          return success(Ending(signal: sig))
    app.runDue(nowMs())
  success(Ending())

proc run*(app: App, ttyPath = "/dev/tty"): Outcome[Ending] {.raises: [].} =
  ## A-1: 端末を raw・代替画面・貼り付けの報告・マウスの報告にして、quit されるか、SIGTERM・SIGHUP・SIGINT が
  ## 届くまで回す。どの終わり方でも端末を戻す。シグナルで終わったときは、その番号を返す
  ## (呼び手は、端末を戻した後にそのシグナルで終わり直せる)。
  let t = ?openTty(ttyPath)
  let watched = watchSignals([SIGWINCH, SIGINT, SIGTERM, SIGHUP, SIGTSTP])
  if watched.isFailure:
    let closed = t.close()
    return failure[Ending]("cannot run the app: ", watched.error & (if closed.isFailure: "; " & closed.error else: ""))
  app.running = true
  var problem = ""
  var ending = Ending()
  let entered = app.enter(t)
  if entered.isFailure: problem = entered.error
  else:
    let r = app.loop(t, watched.get)
    if r.isFailure: problem = r.error
    else: ending = r.get
  let closed = t.close()        # close は restore を含む (TIO T-4)
  if closed.isFailure and problem.len == 0: problem = closed.error
  let unwatched = watched.get.stopWatching()
  if unwatched.isFailure and problem.len == 0: problem = unwatched.error
  if problem.len > 0: return failure[Ending]("the app stopped: ", problem)
  success(ending)
