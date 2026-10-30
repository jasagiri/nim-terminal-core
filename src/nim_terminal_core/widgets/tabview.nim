## 題の帯と、選んだ題の中身だけを見せるウィジェット。規則は ADR-TC-0002 の W-27〜W-29。

import nim_unicode_width
import ../[geometry, canvas, theme, event, widget]

type
  TabPosition* = enum
    tpTop, tpBottom

  Tab = object
    title: string
    content: Widget
    closable: bool

  TabView* = ref object
    widget: Widget
    tabs: seq[Tab]
    active: int
    position*: TabPosition
    opts: WidthOptions   # 前に描いたときの幅の数え方 (押した題を探すのに使う)
    barFocused: bool     # evFocusIn・evFocusOut は本人にだけ届く (子のものは上がってこない)
    onTabChange*: proc(previous, current: int) {.closure, raises: [].}
    onTabClose*: proc(index: int) {.closure, raises: [].}

const CloseMark = "×"

proc widget*(t: TabView): Widget {.raises: [].} = t.widget
proc len*(t: TabView): int {.raises: [].} = t.tabs.len
proc active*(t: TabView): int {.raises: [].} = t.active   ## 選んでいる題。無ければ -1
proc title*(t: TabView, index: int): string {.raises: [].} = t.tabs[index].title
proc content*(t: TabView, index: int): Widget {.raises: [].} = t.tabs[index].content

proc showOnly(t: TabView) =
  ## W-27: 選んだ題の中身だけを見えるようにする (隠れた中身にはフォーカスが行かない。E-9)
  for i, tab in t.tabs: tab.content.visible = i == t.active

proc setActive*(t: TabView, index: int) {.raises: [].} =
  ## W-28: 選ぶ題を index (範囲の外は端) にする。変わったら onTabChange を呼ぶ。
  if t.tabs.len == 0: return
  let previous = t.active
  t.active = max(0, min(index, t.tabs.high))
  t.showOnly()
  if previous != t.active and not t.onTabChange.isNil: t.onTabChange(previous, t.active)

proc addTab*(t: TabView, title: string, content: Widget, closable = false) {.raises: [].} =
  ## 末尾に足す。初めの題なら選ぶ。
  t.tabs.add Tab(title: title, content: content, closable: closable)
  t.widget.add content
  if t.active < 0: t.setActive(0) else: t.showOnly()

proc removeTab*(t: TabView, index: int) {.raises: [].} =
  ## W-29: 題を除く。選んでいた題なら、同じ位置 (末尾なら前) の題を選ぶ。onTabClose を呼ぶ。
  if index < 0 or index >= t.tabs.len: return
  t.tabs[index].content.remove()
  t.tabs.delete(index)
  if not t.onTabClose.isNil: t.onTabClose(index)
  if t.tabs.len == 0:
    t.active = -1
    return
  if index < t.active or t.active >= t.tabs.len: dec t.active
  t.active = max(0, t.active)
  t.showOnly()

proc label(tab: Tab): string = " " & tab.title & (if tab.closable: " " & CloseMark else: "") & " "

proc newTabView*(position = tpTop): TabView {.raises: [].} =
  ## W-27: 帯に題を並べ、選んだ題を roAccent (帯にフォーカスがあれば roSelected)、ほかを roHeader で描く。
  ## 閉じられる題には × を付ける。中身は帯の残りに置く。
  ## W-28: 帯にフォーカスがあれば左右で、中のどこからでも Ctrl+PageUp・Ctrl+PageDown で題を移る。
  ## 題を押すと選び、× を押すと除く (W-29)。
  let t = TabView(active: -1, position: position)
  t.widget = newWidget(arrangement = arCustom, focusable = true)
  t.widget.behavior.arrange = proc(area: Rect, opts: WidthOptions): Rect =
    let body = if t.position == tpTop: rect(area.x, area.y + 1, area.width, area.height - 1)
               else: rect(area.x, area.y, area.width, area.height - 1)
    if t.active >= 0: t.tabs[t.active].content.place(body)
    body
  t.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    let y = if t.position == tpTop: 0 else: c.height - 1
    t.opts = c.widthOptions
    c.fill(rect(0, y, c.width, 1), theme[roHeader])
    var x = 0
    for i, tab in t.tabs:
      let style = if i != t.active: theme[roHeader] elif focused: theme[roSelected] else: theme[roAccent]
      x += c.put(x, y, tab.label, style)
  t.widget.behavior.handle = proc(e: Event): bool =
    case e.kind
    of evKey:
      if e.key.mods == {mCtrl} and e.key.kind in {kPageUp, kPageDown}:
        t.setActive(t.active + (if e.key.kind == kPageUp: -1 else: 1))
        return true
      if t.barFocused and e.key.mods == {} and e.key.kind in {kLeft, kRight}:
        t.setActive(t.active + (if e.key.kind == kLeft: -1 else: 1))
        return true
      false   # 中身の子が扱わなかった左右は、題を動かさない
    of evFocusIn:
      t.barFocused = true
      false
    of evFocusOut:
      t.barFocused = false
      false
    of evPress:
      let barY = if t.position == tpTop: 0 else: t.widget.rect.height - 1
      if e.y != barY: return false
      var x = 0
      for i, tab in t.tabs:
        let w = displayWidth(tab.label, t.opts)
        if e.x >= x and e.x < x + w:
          if tab.closable and e.x >= x + w - 1 - displayWidth(CloseMark, t.opts): t.removeTab(i)
          else: t.setActive(i)
          return true
        x += w
      true
    else: false
  t
