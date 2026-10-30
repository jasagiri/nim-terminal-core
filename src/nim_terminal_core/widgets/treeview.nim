## 木の形の一覧。開く時に子を読み込める (ファイルの木)。規則は ADR-TC-0002 の W-30〜W-32。

import std/unicode
import nim_unicode_width
import ../[geometry, canvas, theme, event, widget]
import ./rows

type
  TreeNode* = ref object
    text*: string
    id*: string
    expanded*: bool
    hasChildren*: bool       ## 子をまだ読み込んでいなくても、開けることを示す
    children: seq[TreeNode]
    parent {.cursor.}: TreeNode

  TreeView* = ref object
    widget: Widget
    roots: seq[TreeNode]
    selected: TreeNode
    top, rows: int
    opts: WidthOptions
    indent*: int
    expandedIcon*, collapsedIcon*, leafIcon*: string
    onSelect*, onActivate*, onExpand*, onCollapse*: proc(node: TreeNode) {.closure, raises: [].}

proc newTreeNode*(text: string, id = "", hasChildren = false): TreeNode {.raises: [].} =
  TreeNode(text: text, id: id, hasChildren: hasChildren)

proc add*(parent, child: TreeNode) {.raises: [].} =
  child.parent = parent
  parent.children.add child

proc clearChildren*(n: TreeNode) {.raises: [].} =
  for c in n.children: c.parent = nil
  n.children.setLen(0)

proc children*(n: TreeNode): seq[TreeNode] {.raises: [].} = n.children
proc parent*(n: TreeNode): TreeNode {.raises: [].} = n.parent
proc canExpand*(n: TreeNode): bool {.raises: [].} = n.children.len > 0 or n.hasChildren

proc widget*(t: TreeView): Widget {.raises: [].} = t.widget
proc selected*(t: TreeView): TreeNode {.raises: [].} = t.selected   ## 無ければ nil
proc top*(t: TreeView): int {.raises: [].} = t.top

proc visibleNodes*(t: TreeView): seq[tuple[node: TreeNode, depth: int]] {.raises: [].} =
  ## W-30: 開いている節の子を、前順に。
  proc walk(n: TreeNode, depth: int, into: var seq[tuple[node: TreeNode, depth: int]]) =
    into.add (n, depth)
    if n.expanded:
      for c in n.children: walk(c, depth + 1, into)
  for r in t.roots: walk(r, 0, result)

proc indexOf(t: TreeView, n: TreeNode): int =
  for i, v in t.visibleNodes:
    if v.node == n: return i
  -1

proc follow(t: TreeView) =
  t.top = followTop(t.top, t.indexOf(t.selected), t.rows, t.visibleNodes.len)

proc select*(t: TreeView, n: TreeNode) {.raises: [].} =
  ## 見えている n を選ぶ。変わったら onSelect を呼ぶ。
  if n.isNil or t.indexOf(n) < 0 or t.selected == n: return
  t.selected = n
  t.follow()
  if not t.onSelect.isNil: t.onSelect(n)

proc setRoots*(t: TreeView, roots: seq[TreeNode]) {.raises: [].} =
  t.roots = roots
  t.selected = nil
  t.top = 0
  if roots.len > 0: t.select(roots[0])

proc expand*(t: TreeView, n: TreeNode) {.raises: [].} =
  ## W-31: 先に onExpand を呼ぶ (そこで子を読み込める)。子が無ければ開かない。
  if n.expanded or not n.canExpand: return
  if not t.onExpand.isNil: t.onExpand(n)
  if n.children.len == 0:
    n.hasChildren = false
    return
  n.expanded = true

proc collapse*(t: TreeView, n: TreeNode) {.raises: [].} =
  ## W-31: 閉じる。選んでいた子孫は、閉じた節に選びを移す。
  if not n.expanded: return
  n.expanded = false
  var p = t.selected
  while not p.isNil:
    if p.parent == n:
      t.select(n)
      break
    p = p.parent
  if not t.onCollapse.isNil: t.onCollapse(n)

proc toggle*(t: TreeView, n: TreeNode) {.raises: [].} =
  if n.expanded: t.collapse(n) else: t.expand(n)

proc moveSelection(t: TreeView, by: int) =
  let nodes = t.visibleNodes
  if nodes.len == 0: return
  let at = t.indexOf(t.selected)
  t.select(nodes[clampIndex((if at < 0: 0 else: at + by), nodes.len)].node)

proc icon(t: TreeView, n: TreeNode): string =
  if not n.canExpand: t.leafIcon elif n.expanded: t.expandedIcon else: t.collapsedIcon

proc newTreeView*(roots: seq[TreeNode] = @[]): TreeView {.raises: [].} =
  ## W-30: 見えている節を 1 行ずつ、深さ × indent だけ字下げし、印 (開いた・閉じた・葉) と文字を描く。
  ## 選んだ行は ListBox と同じに描く (W-12)。
  ## W-32: 上下・PageUp・PageDown・Home・End で選ぶ。右は閉じていれば開き、開いていれば最初の子へ。左は
  ## 開いていれば閉じ、閉じていれば親へ。Space で開け閉め、Enter で onActivate。押すと選び、印を押すと
  ## 開け閉め、ダブルクリックで onActivate。ホイールは選びを変えずに送る。
  let t = TreeView(indent: 2, expandedIcon: "▾ ", collapsedIcon: "▸ ", leafIcon: "  ")
  t.widget = newWidget(focusable = true)
  t.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    t.opts = c.widthOptions
    let nodes = t.visibleNodes
    if c.height != t.rows:
      t.rows = c.height
      t.follow()
    else: t.top = clampTop(t.top, t.rows, nodes.len)
    for row in 0 ..< c.height:
      let i = t.top + row
      if i >= nodes.len: break
      let (n, depth) = nodes[i]
      let style = if n != t.selected: theme[roNormal] elif focused: theme[roSelected] else: theme[roSelectedInactive]
      c.fill(rect(0, row, c.width, 1), style)
      var x = depth * t.indent
      x += c.put(x, row, t.icon(n), style)
      discard c.put(x, row, n.text, style)          # Why discard: 切り抜きが切る
  t.widget.behavior.handle = proc(e: Event): bool =
    case e.kind
    of evKey:
      if e.key.mods != {}: return false
      let s = t.selected
      case e.key.kind
      of kUp: t.moveSelection(-1)
      of kDown: t.moveSelection(1)
      of kPageUp: t.moveSelection(-max(t.rows, 1))
      of kPageDown: t.moveSelection(max(t.rows, 1))
      of kHome: t.moveSelection(-high(int) div 2)
      of kEnd: t.moveSelection(high(int) div 2)
      of kRight:
        if s.isNil: return true
        if not s.expanded: t.expand(s)
        elif s.children.len > 0: t.select(s.children[0])
      of kLeft:
        if s.isNil: return true
        if s.expanded: t.collapse(s)
        elif not s.parent.isNil: t.select(s.parent)
      of kEnter:
        if not s.isNil and not t.onActivate.isNil: t.onActivate(s)
      of kRune:
        if e.key.rune == Rune(' ') and not s.isNil: t.toggle(s) else: return false
      else: return false
      true
    of evPress:
      let nodes = t.visibleNodes
      let i = t.top + e.y
      if e.y < 0 or i >= nodes.len: return true
      let (n, depth) = nodes[i]
      t.select(n)
      let x0 = depth * t.indent
      if e.x >= x0 and e.x < x0 + displayWidth(t.icon(n), t.opts): t.toggle(n)
      true
    of evDoubleClick:
      if not t.selected.isNil and not t.onActivate.isNil: t.onActivate(t.selected)
      true
    of evWheel:
      if e.wheel == maWheelUp: t.top -= 3
      elif e.wheel == maWheelDown: t.top += 3
      else: return false
      t.top = clampTop(t.top, t.rows, t.visibleNodes.len)
      true
    else: false
  t.setRoots(roots)
  t
