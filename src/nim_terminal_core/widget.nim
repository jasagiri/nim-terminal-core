## ウィジェットの木。ウィジェットは型を継がず、振る舞いの手続きの束 (Behavior) に描画・事象・大きさを
## 委ねる。具体のウィジェット (Button など) は自分の状態を持つ ref object で、手続きの束がそれを閉じ込める。
## 置き方 (縦・横・重ね・格子・任意) と大きさの制約は木の側が持ち、計算は layout が行う (ADR-TC-0001 の L-*)。

import std/options
import nim_unicode_width
import ./[geometry, canvas, theme, event]

type
  ConstraintKind* = enum
    ckFill       ## 残りを重みで分ける
    ckFixed      ## セルの数
    ckPercent    ## 使える長さの百分率
    ckNatural       ## ウィジェットが測った大きさ

  Constraint* = object
    kind*: ConstraintKind
    value*: int  ## ckFixed のセル、ckPercent の百分率、ckFill の重み

  Arrangement* = enum
    arNone       ## 子を置かない (葉)
    arVertical   ## 上から下へ
    arHorizontal ## 左から右へ
    arStack      ## 全部の子を同じ所に重ねる (後の子が上)
    arGrid       ## rows × columns の格子に、行の順で
    arCustom     ## behavior.arrange が置く

  Behavior* = object
    render*: proc(c: Canvas, theme: Theme, focused: bool) {.closure, raises: [].}
      ## 自分を描く。子は枠組みが後から描く
    handle*: proc(e: Event): bool {.closure, raises: [].}
      ## 事象を受ける。扱ったら true (親へは渡らない)
    measure*: proc(available: Size, opts: WidthOptions): Size {.closure, raises: [].}
      ## 望む大きさ (余白 margin を除く)。ckNatural の子のときに使う。opts は文字の幅の数え方
    arrange*: proc(content: Rect): Rect {.closure, raises: [].}
      ## arCustom: 子を place で置き、子を切り抜く矩形を返す

  Widget* = ref object
    id*: string
    behavior*: Behavior
    visible*, enabled*, focusable*: bool
    constraint*: Constraint   ## 親の並びの向きの大きさ
    margin*, padding*: Edges
    arrangement*: Arrangement
    gap*: int                 ## 並べる子の間のセル
    rows*, columns*: seq[Constraint]   ## arGrid
    children: seq[Widget]
    parent {.cursor.}: Widget
    rect, shown: Rect         # layout が決める: 置いた所と、そのうち見える所 (画面の位置)

proc fixed*(cells: int): Constraint {.raises: [].} = Constraint(kind: ckFixed, value: cells)
proc percent*(p: int): Constraint {.raises: [].} = Constraint(kind: ckPercent, value: p)
proc fill*(weight = 1): Constraint {.raises: [].} = Constraint(kind: ckFill, value: weight)
proc natural*(): Constraint {.raises: [].} = Constraint(kind: ckNatural)

proc newWidget*(id = "", behavior = Behavior(), arrangement = arNone, focusable = false): Widget {.raises: [].} =
  Widget(id: id, behavior: behavior, visible: true, enabled: true, focusable: focusable,
         constraint: fill(), arrangement: arrangement)

proc children*(w: Widget): seq[Widget] {.raises: [].} = w.children
proc parent*(w: Widget): Widget {.raises: [].} = w.parent   ## 根なら nil
proc rect*(w: Widget): Rect {.raises: [].} = w.rect          ## 置いた所 (画面の位置)
proc shown*(w: Widget): Rect {.raises: [].} = w.shown        ## 見える所 (画面の位置)

proc remove*(child: Widget) {.raises: [].} =
  ## 親から外す。親が無ければ何もしない。
  let p = child.parent
  if p.isNil: return
  for i, c in p.children:
    if c == child:
      p.children.delete(i)
      break
  child.parent = nil

proc add*(parent, child: Widget) {.raises: [].} =
  ## 子を末尾に足す。ほかの親の子なら、そこから外して移す。
  child.remove()
  child.parent = parent
  parent.children.add child

proc insert*(parent, child: Widget, index: int) {.raises: [].} =
  child.remove()
  child.parent = parent
  parent.children.insert(child, max(0, min(index, parent.children.len)))

proc clear*(parent: Widget) {.raises: [].} =
  for c in parent.children: c.parent = nil
  parent.children.setLen(0)

proc find*(w: Widget, id: string): Option[Widget] {.raises: [].} =
  ## w とその子孫から、id のウィジェットを前順で探す。
  if w.id == id: return some(w)
  for c in w.children:
    let found = c.find(id)
    if found.isSome: return found
  none(Widget)

proc isAncestorOf*(a, b: Widget): bool {.raises: [].} =
  ## a が b 自身か、b の祖先か。
  var p = b
  while not p.isNil:
    if p == a: return true
    p = p.parent

proc place*(child: Widget, r: Rect) {.raises: [].} =
  ## arCustom の arrange の中で、子を r (画面の位置) に置く。
  child.rect = r

proc setLayoutResult*(w: Widget, r, shown: Rect) {.raises: [].} =
  ## layout だけが使う。
  w.rect = r
  w.shown = shown

proc sized*(w: Widget, c: Constraint): Widget {.raises: [].} =
  ## 親の並びの向きの大きさを決めて、w を返す (組み立ての式の中で使う)。
  w.constraint = c
  w

proc padded*(w: Widget, e: Edges): Widget {.raises: [].} =
  w.padding = e
  w

proc spaced*(w: Widget, e: Edges): Widget {.raises: [].} =
  ## 外の余白 (margin) を決めて、w を返す。
  w.margin = e
  w

proc container(a: Arrangement, children: openArray[Widget]): Widget =
  result = newWidget(arrangement = a)
  for c in children: result.add c

proc vbox*(children: varargs[Widget]): Widget {.raises: [].} =
  ## 子を上から下へ並べる箱。
  container(arVertical, children)

proc hbox*(children: varargs[Widget]): Widget {.raises: [].} =
  ## 子を左から右へ並べる箱。
  container(arHorizontal, children)

proc stack*(children: varargs[Widget]): Widget {.raises: [].} =
  ## 子を同じ所に重ねる箱 (後の子が上)。
  container(arStack, children)

proc grid*(rows, columns: openArray[Constraint], children: varargs[Widget]): Widget {.raises: [].} =
  ## rows × columns の格子に、子を行の順で置く箱。
  result = container(arGrid, children)
  result.rows = @rows
  result.columns = @columns

proc gapped*(w: Widget, cells: int): Widget {.raises: [].} =
  ## 並べる子の間のセルを決めて、w を返す。
  w.gap = cells
  w

proc named*(w: Widget, id: string): Widget {.raises: [].} =
  w.id = id
  w

proc measure*(w: Widget, available: Size, opts = WidthOptions()): Size {.raises: [].} =
  ## 望む大きさ (margin を除く)。behavior.measure が無ければ、並べる子の大きさの和と padding。
  if not w.visible: return Size()
  if not w.behavior.measure.isNil: return w.behavior.measure(available, opts)
  var inner = Size()
  let room = size(available.width - w.padding.horizontal, available.height - w.padding.vertical)
  var shownCount = 0
  for c in w.children:
    if not c.visible: continue
    inc shownCount
    let m = c.measure(room, opts)
    let mw = m.width + c.margin.horizontal
    let mh = m.height + c.margin.vertical
    case w.arrangement
    of arVertical:
      inner.width = max(inner.width, mw)
      inner.height += mh
    of arHorizontal:
      inner.width += mw
      inner.height = max(inner.height, mh)
    of arStack, arGrid, arCustom, arNone:
      inner.width = max(inner.width, mw)
      inner.height = max(inner.height, mh)
  if shownCount > 1:
    case w.arrangement
    of arVertical: inner.height += w.gap * (shownCount - 1)
    of arHorizontal: inner.width += w.gap * (shownCount - 1)
    else: discard
  size(inner.width + w.padding.horizontal, inner.height + w.padding.vertical)
