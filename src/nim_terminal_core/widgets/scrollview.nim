## 中身を窓より大きく置き、見える所を送るウィジェット。規則は ADR-TC-0002 の W-17〜W-19。

import nim_unicode_width
import ../[geometry, canvas, theme, event, widget]

type
  ScrollView* = ref object
    widget: Widget
    content: Widget
    x, y: int              # 見えている左上 (中身の位置)
    viewport: Rect         # 前に割り付けた窓 (画面の位置)
    contentSize: Size
    step*: int             ## ホイールと矢印で送る行・列の数
    onScroll*: proc(x, y: int) {.closure, raises: [].}

proc widget*(s: ScrollView): Widget {.raises: [].} = s.widget
proc content*(s: ScrollView): Widget {.raises: [].} = s.content
proc offset*(s: ScrollView): tuple[x, y: int] {.raises: [].} = (s.x, s.y)

proc limits(s: ScrollView): tuple[x, y: int] =
  (max(0, s.contentSize.width - s.viewport.width), max(0, s.contentSize.height - s.viewport.height))

proc scrollTo*(s: ScrollView, x, y: int) {.raises: [].} =
  ## W-18: 中身の端を越えないよう収めて送る。変わったら onScroll を呼ぶ。
  let (mx, my) = s.limits
  let nx = max(0, min(x, mx))
  let ny = max(0, min(y, my))
  if nx == s.x and ny == s.y: return
  s.x = nx
  s.y = ny
  if not s.onScroll.isNil: s.onScroll(nx, ny)

proc scrollBy*(s: ScrollView, dx, dy: int) {.raises: [].} = s.scrollTo(s.x + dx, s.y + dy)
proc scrollToTop*(s: ScrollView) {.raises: [].} = s.scrollTo(s.x, 0)
proc scrollToBottom*(s: ScrollView) {.raises: [].} = s.scrollTo(s.x, high(int) div 2)

proc ensureVisible*(s: ScrollView, child: Widget) {.raises: [].} =
  ## W-18: 中身の中の child (前に割り付けた所) が窓に入るよう送る。
  let r = child.rect
  if r.isEmpty: return
  var nx = s.x
  var ny = s.y
  let left = r.x - s.content.rect.x
  let top = r.y - s.content.rect.y
  if left < nx: nx = left
  elif left + r.width > nx + s.viewport.width: nx = left + r.width - s.viewport.width
  if top < ny: ny = top
  elif top + r.height > ny + s.viewport.height: ny = top + r.height - s.viewport.height
  s.scrollTo(nx, ny)

proc newScrollView*(content: Widget, step = 1): ScrollView {.raises: [].} =
  ## W-17: 中身を、窓の大きさと中身が測った大きさの大きいほうで置き、見えている左上の分だけずらす。
  ## 縦に溢れれば右の 1 列に、横に溢れれば下の 1 行に、つまみの付いた棒を描く (棒の分だけ窓が狭まる)。
  ## W-19: ホイール、上下左右、PageUp・PageDown、Home・End で送る (中の子が扱わなかったもの)。
  let s = ScrollView(content: content, step: max(step, 1))
  s.widget = newWidget(arrangement = arCustom)
  s.widget.add content
  s.widget.behavior.arrange = proc(area: Rect, opts: WidthOptions): Rect =
    var view = area
    var want = content.measure(size(area.width, area.height), opts)
    if want.height > view.height: view.width = max(0, view.width - 1)
    if want.width > view.width: view.height = max(0, view.height - 1)
    if want.height > view.height and view.width == area.width: view.width = max(0, view.width - 1)
    want = content.measure(size(view.width, view.height), opts)
    s.contentSize = size(max(want.width, view.width), max(want.height, view.height))
    s.viewport = view
    let (mx, my) = s.limits
    s.x = min(s.x, mx)
    s.y = min(s.y, my)
    content.place(rect(view.x - s.x, view.y - s.y, s.contentSize.width, s.contentSize.height))
    view
  s.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    let vx = s.viewport.x - s.widget.rect.x
    let vy = s.viewport.y - s.widget.rect.y
    let (mx, my) = s.limits
    if my > 0 and s.viewport.height > 0:            # 縦の棒
      let h = s.viewport.height
      let thumb = max(1, h * h div s.contentSize.height)
      let at = (h - thumb) * s.y div my
      for row in 0 ..< h:
        if row >= at and row < at + thumb: discard c.put(vx + s.viewport.width, vy + row, " ", theme[roFocused])
        else: discard c.put(vx + s.viewport.width, vy + row, theme.border.vertical, theme[roBorder])
    if mx > 0 and s.viewport.width > 0:             # 横の棒
      let w = s.viewport.width
      let thumb = max(1, w * w div s.contentSize.width)
      let at = (w - thumb) * s.x div mx
      for col in 0 ..< w:
        if col >= at and col < at + thumb: discard c.put(vx + col, vy + s.viewport.height, " ", theme[roFocused])
        else: discard c.put(vx + col, vy + s.viewport.height, theme.border.horizontal, theme[roBorder])
  s.widget.behavior.handle = proc(e: Event): bool =
    case e.kind
    of evWheel:
      case e.wheel
      of maWheelUp: s.scrollBy(0, -3 * s.step)
      of maWheelDown: s.scrollBy(0, 3 * s.step)
      of maWheelLeft: s.scrollBy(-3 * s.step, 0)
      of maWheelRight: s.scrollBy(3 * s.step, 0)
      else: return false
      true
    of evKey:
      if e.key.mods != {}: return false
      case e.key.kind
      of kUp: s.scrollBy(0, -s.step)
      of kDown: s.scrollBy(0, s.step)
      of kLeft: s.scrollBy(-s.step, 0)
      of kRight: s.scrollBy(s.step, 0)
      of kPageUp: s.scrollBy(0, -max(s.viewport.height - 1, 1))
      of kPageDown: s.scrollBy(0, max(s.viewport.height - 1, 1))
      of kHome: s.scrollToTop()
      of kEnd: s.scrollToBottom()
      else: return false
      true
    else: false
  s.widget.behavior.measure = proc(available: Size, opts: WidthOptions): Size =
    let m = content.measure(available, opts)
    size(min(m.width, available.width), min(m.height, available.height))
  s
