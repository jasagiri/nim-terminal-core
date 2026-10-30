## ウィジェットの木を矩形に割り付ける。規則は ADR-TC-0001 の L-1〜L-10。I/O を持たない。

import std/algorithm
import nim_unicode_width
import ./[geometry, widget]

proc solve*(total: int, constraints: openArray[Constraint], autos: openArray[int] = [],
            gap = 0): seq[tuple[offset, size: int]] {.raises: [].} =
  ## 1 つの向きの割り付け。autos は ckNatural の項の測った大きさ (同じ位置)。
  ## L-2: 固定・百分率・測った大きさを先に取り、残りを ckFill に重みで分ける (割り切れない分は前の項から 1 ずつ)。
  ## L-3: 百分率の端数は、大きい順に 1 ずつ足し、合わせて百分率の和の分になるようにする。
  ## L-4: 使える長さを越えたら、後ろの項から削る。
  let n = constraints.len
  if n == 0: return
  let avail = max(0, total - gap * (n - 1))
  var sizes = newSeq[int](n)
  var remainders: seq[tuple[rem, index: int]]
  var exact, floors = 0
  for i, c in constraints:
    case c.kind
    of ckFixed: sizes[i] = max(c.value, 0)
    of ckNatural: sizes[i] = (if i < autos.len: max(autos[i], 0) else: 0)
    of ckPercent:
      let num = max(c.value, 0) * avail
      sizes[i] = num div 100
      floors += sizes[i]
      exact += num
      remainders.add (rem: num mod 100, index: i)
    of ckFill: discard
  remainders.sort(proc(a, b: tuple[rem, index: int]): int =
    if a.rem != b.rem: cmp(b.rem, a.rem) else: cmp(a.index, b.index))
  var extra = (exact + 50) div 100 - floors
  for r in remainders:
    if extra <= 0: break
    inc sizes[r.index]
    dec extra
  var used = 0
  for s in sizes: used += s
  var rest = avail - used
  if rest > 0:
    var weights = 0
    for c in constraints:
      if c.kind == ckFill: weights += max(c.value, 1)
    if weights > 0:
      var given = 0
      for i, c in constraints:
        if c.kind == ckFill:
          sizes[i] = rest * max(c.value, 1) div weights
          given += sizes[i]
      var left = rest - given
      for i, c in constraints:
        if left == 0: break
        if c.kind == ckFill:
          inc sizes[i]
          dec left
  elif rest < 0:
    var over = -rest
    for i in countdown(n - 1, 0):
      let cut = min(over, sizes[i])
      sizes[i] -= cut
      over -= cut
      if over == 0: break
  var at = 0
  for i in 0 ..< n:
    result.add (offset: min(at, total), size: sizes[i])
    at += sizes[i] + gap

proc arrange(w: Widget, r, clip: Rect, opts: WidthOptions) {.raises: [].}

proc line(w: Widget, content, clip: Rect, vertical: bool, opts: WidthOptions) =
  ## L-1、L-7、L-8: 見える子を並びの向きに割り付け、交わる向きは content の全体
  var shownKids: seq[Widget]
  for c in w.children:
    if c.visible: shownKids.add c
    else: arrange(c, Rect(), Rect(), opts)
  var cs: seq[Constraint]
  var autos: seq[int]
  for c in shownKids:
    cs.add c.constraint
    if c.constraint.kind == ckNatural:
      let m = c.measure(content.size, opts)
      autos.add(if vertical: m.height + c.margin.vertical else: m.width + c.margin.horizontal)
    else: autos.add 0
  let total = if vertical: content.height else: content.width
  let parts = solve(total, cs, autos, w.gap)
  for i, c in shownKids:
    let slot =
      if vertical: rect(content.x, content.y + parts[i].offset, content.width, parts[i].size)
      else: rect(content.x + parts[i].offset, content.y, parts[i].size, content.height)
    arrange(c, slot.inset(c.margin), clip, opts)

proc arrange(w: Widget, r, clip: Rect, opts: WidthOptions) {.raises: [].} =
  let shown = if w.visible: intersect(r, clip) else: Rect()
  w.setLayoutResult(if w.visible: r else: Rect(), shown)
  let content = r.inset(w.padding)
  var kidsClip = intersect(shown, content)
  if not w.visible:
    for c in w.children: arrange(c, Rect(), Rect(), opts)
    return
  case w.arrangement
  of arNone:
    for c in w.children: arrange(c, Rect(), Rect(), opts)
  of arVertical: w.line(content, kidsClip, true, opts)
  of arHorizontal: w.line(content, kidsClip, false, opts)
  of arStack:   # L-6
    for c in w.children: arrange(c, content.inset(c.margin), kidsClip, opts)
  of arGrid:    # L-5
    let rowParts = solve(content.height, w.rows, [], w.gap)
    let colParts = solve(content.width, w.columns, [], w.gap)
    var k = 0
    for c in w.children:
      if not c.visible:
        arrange(c, Rect(), Rect(), opts)
        continue
      let row = if w.columns.len > 0: k div w.columns.len else: w.rows.len
      let col = if w.columns.len > 0: k mod w.columns.len else: 0
      inc k
      if row < w.rows.len:
        let cell = rect(content.x + colParts[col].offset, content.y + rowParts[row].offset,
                        colParts[col].size, rowParts[row].size)
        arrange(c, cell.inset(c.margin), kidsClip, opts)
      else: arrange(c, Rect(), Rect(), opts)
  of arCustom:
    if w.behavior.arrange.isNil:
      for c in w.children: arrange(c, Rect(), Rect(), opts)
    else:
      for c in w.children: c.place(Rect())   # 置かれなかった子は見えない (前の所に残さない)
      kidsClip = intersect(shown, w.behavior.arrange(content, opts))
      for c in w.children: arrange(c, if c.visible: c.rect else: Rect(), kidsClip, opts)

proc layout*(root: Widget, area: Rect, opts = WidthOptions()) {.raises: [].} =
  ## L-9: 木の全体を area に割り付ける。同じ木と大きさなら、何度呼んでも同じ結果。
  ## L-10: 各ウィジェットの見える所は、置いた所と、親の子を切り抜く矩形 (padding の内側) の重なり。
  arrange(root, area, area, opts)
