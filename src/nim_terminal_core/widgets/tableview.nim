## 見出しのある表。列の幅は割り付け (L-2) で決め、見出しを押すと並べ替える。規則は ADR-TC-0002 の W-33〜W-35。

import std/algorithm
import nim_unicode_width
import ../[geometry, canvas, theme, event, widget, layout]
import ./[rows, label]

export Align

type
  SortDirection* = enum
    sdAscending, sdDescending

  Column* = object
    title*: string
    width*: Constraint
    align*: Align

  TableView* = ref object
    widget: Widget
    columns: seq[Column]
    rows: seq[seq[string]]
    selected: int
    top, shown: int
    sortColumn: int
    sortDirection: SortDirection
    opts: WidthOptions
    onSelect*, onActivate*: proc(row: int) {.closure, raises: [].}
    onSort*: proc(column: int, direction: SortDirection) {.closure, raises: [].}

proc column*(title: string, width = fill(), align = alLeft): Column {.raises: [].} =
  Column(title: title, width: width, align: align)

proc widget*(t: TableView): Widget {.raises: [].} = t.widget
proc rows*(t: TableView): seq[seq[string]] {.raises: [].} = t.rows
proc selected*(t: TableView): int {.raises: [].} = t.selected   ## 無ければ -1
proc sortedBy*(t: TableView): tuple[column: int, direction: SortDirection] {.raises: [].} =
  (t.sortColumn, t.sortDirection)

proc cell*(t: TableView, row, col: int): string {.raises: [].} =
  if row < 0 or row >= t.rows.len or col < 0 or col >= t.rows[row].len: "" else: t.rows[row][col]

proc select*(t: TableView, row: int) {.raises: [].} =
  let before = t.selected
  t.selected = clampIndex(row, t.rows.len)
  t.top = followTop(t.top, t.selected, t.shown, t.rows.len)
  if t.selected != before and t.selected >= 0 and not t.onSelect.isNil: t.onSelect(t.selected)

proc setRows*(t: TableView, rows: seq[seq[string]]) {.raises: [].} =
  ## 行を置き換え、最初の行を選ぶ。並べ替えていれば並べ直す。
  t.rows = rows
  t.selected = -1
  t.top = 0
  if t.sortColumn >= 0:
    let c = t.sortColumn
    let d = t.sortDirection
    t.rows.sort(proc(a, b: seq[string]): int =
      let x = (if c < a.len: a[c] else: "")
      let y = (if c < b.len: b[c] else: "")
      if d == sdAscending: cmp(x, y) else: cmp(y, x))
  t.select(0)

proc addRow*(t: TableView, row: seq[string]) {.raises: [].} =
  t.rows.add row
  if t.selected < 0: t.select(0)

proc sortBy*(t: TableView, column: int, direction: SortDirection) {.raises: [].} =
  ## W-34: column の文字で並べ替える (同じ文字の行は前の順を保つ)。選んでいた行は、並べ替えた後も選ぶ。
  ## onSort があれば、並べ替えはそれに任せる (呼び手が setRows し直す)。
  if column < 0 or column >= t.columns.len: return
  t.sortColumn = column
  t.sortDirection = direction
  if not t.onSort.isNil:
    t.onSort(column, direction)
    return
  var order: seq[int]
  for i in 0 ..< t.rows.len: order.add i
  let rs = t.rows
  order.sort(proc(a, b: int): int =
    let x = (if column < rs[a].len: rs[a][column] else: "")
    let y = (if column < rs[b].len: rs[b][column] else: "")
    let c = if direction == sdAscending: cmp(x, y) else: cmp(y, x)
    if c != 0: c else: cmp(a, b))
  var sorted: seq[seq[string]]
  var at = -1
  for k, i in order:
    sorted.add rs[i]
    if i == t.selected: at = k
  t.rows = sorted
  t.selected = -1
  if at >= 0:
    t.selected = at
    t.top = followTop(t.top, t.selected, t.shown, t.rows.len)

proc widths(t: TableView, total: int): seq[tuple[offset, size: int]] =
  var cs: seq[Constraint]
  var naturals: seq[int]
  for i, c in t.columns:
    cs.add c.width
    var w = displayWidth(c.title, t.opts) + 2
    if c.width.kind == ckNatural:
      for r in t.rows:
        if i < r.len: w = max(w, displayWidth(r[i], t.opts))
    naturals.add w
  solve(total, cs, naturals, 1)

proc drawCell(c: Canvas, x, y, width: int, text: string, align: Align, style: Style) =
  let s = c.fit(text, width)
  let w = c.textWidth(s)
  let at = case align
    of alLeft: 0
    of alCenter: (width - w) div 2
    of alRight: width - w
  discard c.put(x + at, y, s, style)          # Why discard: fit で収めた

proc newTableView*(columns: openArray[Column]): TableView {.raises: [].} =
  ## W-33: 1 行目に見出しを roHeader で、並べ替えた列には ▲ (昇順) か ▼ (降順) を付けて描く。その下に行を
  ## 描き、選んだ行は ListBox と同じに描く。列の幅は列の制約を L-2 で割り付けて決め (natural は見出しと
  ## 中身の一番長い幅)、列の間を 1 列あける。セルは幅に収めて揃える。
  ## W-35: 上下・PageUp・PageDown・Home・End で選び、Enter で onActivate。行を押すと選び、ダブルクリックで
  ## onActivate。見出しを押すと、その列で並べ替える (同じ列なら向きを替える。W-34)。ホイールで送る。
  let t = TableView(columns: @columns, selected: -1, sortColumn: -1)
  t.widget = newWidget(focusable = true)
  t.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    t.opts = c.widthOptions
    let body = max(c.height - 1, 0)
    if body != t.shown:
      t.shown = body
      t.top = followTop(t.top, t.selected, t.shown, t.rows.len)
    else: t.top = clampTop(t.top, t.shown, t.rows.len)
    let ws = t.widths(c.width)
    c.fill(rect(0, 0, c.width, 1), theme[roHeader])
    for i, col in t.columns:
      var title = col.title
      if i == t.sortColumn: title.add(if t.sortDirection == sdAscending: " ▲" else: " ▼")
      c.drawCell(ws[i].offset, 0, ws[i].size, title, col.align, theme[roHeader])
    for row in 0 ..< body:
      let r = t.top + row
      if r >= t.rows.len: break
      let style = if r != t.selected: theme[roNormal] elif focused: theme[roSelected] else: theme[roSelectedInactive]
      c.fill(rect(0, row + 1, c.width, 1), style)
      for i, col in t.columns:
        c.drawCell(ws[i].offset, row + 1, ws[i].size, t.cell(r, i), col.align, style)
  t.widget.behavior.handle = proc(e: Event): bool =
    case e.kind
    of evKey:
      if e.key.mods != {}: return false
      case e.key.kind
      of kUp: t.select(t.selected - 1)
      of kDown: t.select(t.selected + 1)
      of kPageUp: t.select(t.selected - max(t.shown, 1))
      of kPageDown: t.select(t.selected + max(t.shown, 1))
      of kHome: t.select(0)
      of kEnd: t.select(t.rows.high)
      of kEnter:
        if t.selected >= 0 and not t.onActivate.isNil: t.onActivate(t.selected)
      else: return false
      true
    of evPress:
      if e.y == 0:
        let ws = t.widths(t.widget.rect.width)
        for i, w in ws:
          if e.x >= w.offset and e.x < w.offset + w.size:
            let dir = if i == t.sortColumn and t.sortDirection == sdAscending: sdDescending else: sdAscending
            t.sortBy(i, dir)
            break
      elif t.top + e.y - 1 < t.rows.len: t.select(t.top + e.y - 1)
      true
    of evDoubleClick:
      if e.y > 0 and t.selected >= 0 and not t.onActivate.isNil: t.onActivate(t.selected)
      true
    of evWheel:
      if e.wheel == maWheelUp: t.top -= 3
      elif e.wheel == maWheelDown: t.top += 3
      else: return false
      t.top = clampTop(t.top, t.shown, t.rows.len)
      true
    else: false
  t
