## 行の一覧から 1 つを選ぶウィジェット。当たった文字の強調 (絞り込みの結果) を持てる。
## 規則は ADR-TC-0002 の W-10〜W-13。

import nim_unicode_width
import ../[geometry, canvas, theme, event, widget]

type
  ListItem* = object
    text*: string
    spans*: seq[Slice[int]]   ## 強調するバイトの範囲 (nim-line-filter の Match.spans の形)

  ListBox* = ref object
    widget: Widget
    items: seq[ListItem]
    selected: int             # 項目が無ければ -1
    top: int                  # 見えている最初の項目
    rows: int                 # 前に描いたときの行の数
    onSelect*: proc(index: int) {.closure, raises: [].}
    onActivate*: proc(index: int) {.closure, raises: [].}

const TabStop = 8
const WheelStep = 3

proc widget*(l: ListBox): Widget {.raises: [].} = l.widget
proc items*(l: ListBox): seq[ListItem] {.raises: [].} = l.items
proc len*(l: ListBox): int {.raises: [].} = l.items.len
proc selected*(l: ListBox): int {.raises: [].} = l.selected   ## 選んでいる項目。無ければ -1
proc top*(l: ListBox): int {.raises: [].} = l.top

proc item*(text: string, spans: seq[Slice[int]] = @[]): ListItem {.raises: [].} =
  ListItem(text: text, spans: spans)

proc follow(l: ListBox) =
  ## W-11: 選んでいる項目が見えるよう、見える範囲を動かす
  if l.selected < 0: return
  if l.selected < l.top: l.top = l.selected
  if l.rows > 0 and l.selected >= l.top + l.rows: l.top = l.selected - l.rows + 1

proc clampTop(l: ListBox) =
  l.top = max(0, min(l.top, max(0, l.items.len - max(l.rows, 1))))

proc select*(l: ListBox, index: int) {.raises: [].} =
  ## W-11: 選ぶ項目を index (範囲の外は端) にし、見えるようにする。変わったら onSelect を呼ぶ。
  let before = l.selected
  l.selected = if l.items.len == 0: -1 else: max(0, min(index, l.items.high))
  l.follow()
  if l.selected != before and l.selected >= 0 and not l.onSelect.isNil: l.onSelect(l.selected)

proc moveSelection*(l: ListBox, by: int) {.raises: [].} =
  l.select(if l.selected < 0: 0 else: l.selected + by)

proc setItems*(l: ListBox, items: seq[ListItem], selected = 0) {.raises: [].} =
  ## W-10: 項目を置き換えて selected を選ぶ (無ければ -1)。
  l.items = items
  l.selected = -1
  l.top = 0
  l.select(selected)

proc pageRows*(l: ListBox): int {.raises: [].} = max(l.rows, 1)

proc touches(spans: seq[Slice[int]], bytes: Slice[int]): bool =
  for s in spans:
    if s.a <= bytes.b and bytes.a <= s.b: return true

proc drawItem(c: Canvas, y: int, it: ListItem, base, match: Style) =
  ## W-12: タブを 8 列の境まで空白にし、spans に触れるクラスタを match で描く
  var col = 0
  for cl in clusters(it.text, c.widthOptions):
    if col >= c.width: break
    let t = it.text[cl.bytes]
    if t == "\t":
      let stop = (col div TabStop + 1) * TabStop
      while col < stop: col += c.put(col, y, " ", base)
      continue
    col += c.put(col, y, t, if it.spans.touches(cl.bytes): match else: base)
  if col < c.width: c.fill(rect(col, y, c.width - col, 1), base)

proc newListBox*(items: seq[ListItem] = @[]): ListBox {.raises: [].} =
  ## W-12: 見えている項目を 1 行ずつ描き、選んでいる行は、フォーカスがあれば roSelected、無ければ
  ## roSelectedInactive で右の端まで描く。強調は roMatch (選んだ行では反転を重ねる)。
  ## W-13: 上下・PageUp・PageDown・Home・End で選び、Enter で onActivate。押した行を選び、
  ## ダブルクリックで onActivate。ホイールは選びを変えずに 3 行ずつ送る。
  let l = ListBox(selected: -1)
  l.widget = newWidget(focusable = true)
  l.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    l.rows = c.height
    l.follow()
    l.clampTop()
    for row in 0 ..< c.height:
      let i = l.top + row
      if i >= l.items.len: break
      var base = theme[roNormal]
      var match = theme[roMatch]
      if i == l.selected:
        base = if focused: theme[roSelected] else: theme[roSelectedInactive]
        match.reverse = base.reverse
        match.underline = match.underline or base.underline
      c.drawItem(row, l.items[i], base, match)
  l.widget.behavior.handle = proc(e: Event): bool =
    case e.kind
    of evKey:
      if e.key.mods != {}: return false
      case e.key.kind
      of kUp: l.moveSelection(-1)
      of kDown: l.moveSelection(1)
      of kPageUp: l.moveSelection(-l.pageRows)
      of kPageDown: l.moveSelection(l.pageRows)
      of kHome: l.select(0)
      of kEnd: l.select(l.items.high)
      of kEnter:
        if l.selected >= 0 and not l.onActivate.isNil: l.onActivate(l.selected)
      else: return false
      true
    of evPress:
      if l.top + e.y < l.items.len and e.y >= 0: l.select(l.top + e.y)
      true
    of evDoubleClick:
      if l.selected >= 0 and l.top + e.y == l.selected and not l.onActivate.isNil: l.onActivate(l.selected)
      true
    of evWheel:
      if e.wheel == maWheelUp: l.top -= WheelStep
      elif e.wheel == maWheelDown: l.top += WheelStep
      else: return false
      l.clampTop()
      true
    else: false
  l.widget.behavior.measure = proc(available: Size, opts: WidthOptions): Size =
    var w = 0
    for it in l.items: w = max(w, displayWidth(it.text, opts))
    size(w, l.items.len)
  l.setItems(items)
  l
