## TC-W-17〜35: ScrollView・Dialog・Menu・TabView・TreeView・TableView。描いた画面を読み戻して確かめる。

import std/[unittest, unicode, strutils]
import nim_terminal_core

proc rows(s: Surface): seq[string] =
  for y in 0 ..< s.screen.height:
    var r = ""
    for x in 0 ..< s.screen.width: r.add s.screen.cellText(x, y)
    result.add r

proc shot(app: App): seq[string] = app.draw().rows

proc key(c: char, mods: set[KeyMod] = {}): KeyEvent = KeyEvent(kind: kRune, rune: Rune(ord(c)), mods: mods)
proc key(k: KeyKind, mods: set[KeyMod] = {}): KeyEvent = KeyEvent(kind: k, mods: mods)
proc mouse(a: MouseAction, x, y: int, b = mbLeft): KeyEvent =
  KeyEvent(kind: kMouse, mouse: MouseInfo(action: a, button: b, x: x, y: y))
proc click(app: App, x, y: int, at: int64 = 0) =
  app.feed(mouse(maPress, x, y), at)
  app.feed(mouse(maRelease, x, y), at)

proc lines(n: int): Widget =
  var ls: seq[Widget]
  for i in 0 ..< n: ls.add newLabel("line " & $i).widget
  vbox(ls)

suite "scrollview":
  test "TC-W-17 Given content taller than the view When drawn Then the top part shows and a scroll bar takes the right column":
    let s = newScrollView(lines(10))
    let app = newApp(vbox(s.widget))
    app.resize(8, 3)
    let r = app.shot
    check r[0].startsWith("line 0") and r[2].startsWith("line 2")
    check r[0][7] == ' ' and r[2].endsWith("│")       # つまみは上、残りは線

  test "TC-W-18 Given a scroll view When scrolled past the end Then it stops at the end, tells onScroll, and ensureVisible brings a child in":
    let content = lines(10)
    let s = newScrollView(content)
    var told: seq[int]
    s.onScroll = proc(x, y: int) = told.add y
    let app = newApp(vbox(s.widget))
    app.resize(8, 3)
    discard app.draw()
    s.scrollBy(0, 100)
    check s.offset == (x: 0, y: 7)
    check app.shot[2].startsWith("line 9")
    s.scrollTo(0, 0)
    discard app.draw()
    s.ensureVisible(content.children[5])
    check s.offset.y == 3 and told == @[7, 0, 3]

  test "TC-W-19 Given a scroll view When the wheel, arrows and PageDown come Then it scrolls; a focused child's keys come first":
    let input = newTextInput("abc")
    let s = newScrollView(vbox(input.widget, lines(10)))
    let app = newApp(vbox(s.widget))
    app.resize(8, 3)
    discard app.draw()
    app.feed(mouse(maWheelDown, 1, 1, mbNone), 0)
    check s.offset.y == 3
    app.feed(key(kLeft), 0)                     # 入力欄が扱う
    check s.offset.y == 3 and input.lineEdit.cursor == 2
    app.feed(key(kDown), 0)
    app.feed(key(kPageDown), 0)
    check s.offset.y == 6

suite "dialog":
  test "TC-W-20 Given a dialog When shown Then a framed box with the title, the wrapped message and the buttons is centered":
    let d = newDialog("確認", "Delete it?", ["Yes", "No"])
    let app = newApp(newWidget())
    app.resize(30, 9)
    d.show(app)
    let r = app.shot
    check r[2] == "     ┌─ 確認 ──────────┐      "
    check r[3] == "     │ Delete it?      │      "
    check r[5] == "     │  [ Yes ] [ No ] │      "
    check r[6] == "     └─────────────────┘      "

  test "TC-W-21 Given a shown dialog When a button is pressed or Esc comes Then it closes with that choice and focus returns":
    let before = newButton("open")
    let app = newApp(vbox(before.widget))
    app.resize(30, 9)
    discard app.draw()
    var choices: seq[int]
    let d = newDialog("Q", "?", ["Yes", "No"])
    d.onClose = proc(c: int) = choices.add c
    d.show(app)
    discard app.draw()
    check app.focused == d.buttons[0].widget
    app.feed(key(kTab), 0)
    app.feed(key(kEnter), 0)
    check choices == @[1] and not d.isShown and app.focused == before.widget
    d.show(app)
    app.feed(key(kEscape), 0)
    check choices == @[1, Cancelled]
    d.show(app)
    app.feed(key(kEnter), 0)                 # 最初のボタン (どのボタンも自分の番号で閉じる)
    check choices == @[1, Cancelled, 0]

  test "TC-W-22 Given a dialog with buttons When Left and Right come Then focus moves between the buttons":
    let app = newApp(newWidget())
    app.resize(30, 9)
    let d = newDialog("Q", "?", ["A", "B", "C"])
    d.show(app)
    app.feed(key(kRight), 0)
    app.feed(key(kRight), 0)
    app.feed(key(kRight), 0)
    check app.focused == d.buttons[2].widget
    app.feed(key(kLeft), 0)
    check app.focused == d.buttons[1].widget

suite "menu":
  proc sample(log: ref seq[string]): Menu =
    let sub = newMenu([menuItem("Deep", proc() = log[].add "deep")])
    newMenu([menuItem("Open", (proc() = log[].add "open"), "Ctrl+O"), separator(),
             menuItem("Gone", enabled = false), submenuItem("More", sub), menuItem("Quit", proc() = log[].add "quit")])

  test "TC-W-23 Given a menu When popped up Then items, shortcuts, the separator and the submenu mark are drawn":
    let log = new seq[string]
    let m = sample(log)
    let app = newApp(newWidget())
    app.resize(20, 8)
    m.popup(app, 1, 0)
    let r = app.shot
    check r[1].contains("│ Open  Ctrl+O │")
    check r[2].contains("├") or r[2].contains("─────")
    check r[4].contains("More") and r[4].contains("▸")

  test "TC-W-24 Given a menu When Up and Down move Then separators and disabled items are skipped, wrapping; Enter runs the item and closes all":
    let log = new seq[string]
    let m = sample(log)
    let app = newApp(newWidget())
    app.resize(20, 8)
    m.popup(app, 0, 0)
    check m.active == 0
    app.feed(key(kDown), 0)
    check m.active == 3
    app.feed(key(kDown), 0)
    app.feed(key(kDown), 0)
    check m.active == 0
    app.feed(key(kUp), 0)
    app.feed(key(kUp), 0)
    app.feed(key(kRight), 0)                 # More を開く
    check m.active == 3
    app.feed(key(kEnter), 0)                 # Deep
    check log[] == @["deep"] and not m.isShown

  test "TC-W-25 Given a popped up menu When pressed outside or Esc comes Then it closes and onClose runs":
    let log = new seq[string]
    let m = sample(log)
    var closes = 0
    m.onClose = proc() = inc closes
    let app = newApp(newWidget())
    app.resize(20, 8)
    m.popup(app, 0, 0)
    discard app.draw()
    app.feed(mouse(maPress, 19, 7), 0)
    check not m.isShown and closes == 1
    m.popup(app, 0, 0)
    app.feed(key(kEscape), 0)
    check not m.isShown and closes == 2
    m.popup(app, 0, 0)
    discard app.draw()
    app.feed(mouse(maPress, 3, 5), 0)        # Quit の行 (枠の 1 行の下の 5 項目め)
    check log[] == @["quit"]

  test "TC-W-26 Given a menu bar When a title is opened and Right comes in its menu Then the next title's menu opens under it":
    let log = new seq[string]
    let file = newMenu([menuItem("New", proc() = log[].add "new")])
    let edit = newMenu([menuItem("Copy", proc() = log[].add "copy")])
    let app = newApp(newWidget())
    let bar = newMenuBar(app, [("File", file), ("Edit", edit)])
    app.root = vbox(bar.widget, newWidget())
    app.resize(20, 6)
    let r = app.shot
    check r[0].startsWith(" File  Edit ")
    app.feed(key(kEnter), 0)
    check file.isShown
    app.feed(key(kRight), 0)
    check edit.isShown and not file.isShown
    discard app.draw()
    check edit.widget.rect.x == 6 and edit.widget.rect.y == 1
    app.feed(key(kEnter), 0)
    check log[] == @["copy"]

suite "tabview":
  test "TC-W-27 Given tabs When drawn Then the bar lists titles with a close mark and only the active content shows":
    let t = newTabView()
    t.addTab("一", newLabel("first").widget)
    t.addTab("two", newLabel("second").widget, closable = true)
    let app = newApp(vbox(t.widget))
    app.resize(16, 3)
    let r = app.shot
    check r[0].startsWith(" 一  two × ")
    check r[1].startsWith("first")
    check not t.content(1).visible

  test "TC-W-28 Given tabs When the bar is focused and Right comes, or Ctrl+PageDown comes from inside Then the next tab shows":
    let t = newTabView()
    let input = newTextInput("x")
    t.addTab("a", input.widget)
    t.addTab("b", newButton("B").widget)
    t.addTab("c", newLabel("C").widget)
    var changes: seq[(int, int)]
    t.onTabChange = proc(p, c: int) = changes.add (p, c)
    let app = newApp(vbox(t.widget))
    app.resize(16, 3)
    discard app.draw()
    check app.focused == t.widget
    app.feed(key(kRight), 0)
    check t.active == 1
    check app.focus(t.content(1))
    app.feed(key(kPageDown, {mCtrl}), 0)
    check t.active == 2 and changes == @[(0, 1), (1, 2)]
    discard app.draw()
    check app.focused == t.widget              # 隠れた題の中身からフォーカスが外れた

  test "TC-W-29 Given tabs When a tab title or its close mark is pressed Then it is selected or removed, keeping a neighbour active":
    let t = newTabView()
    t.addTab("a", newWidget(), closable = true)
    t.addTab("b", newWidget(), closable = true)
    t.addTab("c", newWidget())
    var closed: seq[int]
    t.onTabClose = proc(i: int) = closed.add i
    let app = newApp(vbox(t.widget))
    app.resize(20, 3)
    discard app.draw()
    app.click(7, 0)                          # " b × " の b
    check t.active == 1
    app.click(9, 0)                          # b の ×
    check closed == @[1] and t.len == 2 and t.active == 1 and t.title(1) == "c"
    t.removeTab(1)
    check t.active == 0

suite "treeview":
  proc sampleTree(): seq[TreeNode] =
    let root = newTreeNode("src")
    let a = newTreeNode("a.nim")
    let lib = newTreeNode("lib", hasChildren = true)
    root.add a
    root.add lib
    @[root, newTreeNode("README")]

  test "TC-W-30 Given a tree When drawn Then open nodes show their children indented, with marks":
    let roots = sampleTree()
    roots[0].expanded = true
    let t = newTreeView(roots)
    let app = newApp(vbox(t.widget))
    app.resize(12, 4)
    check app.shot == @["▾ src       ", "    a.nim   ", "  ▸ lib     ", "  README    "]

  test "TC-W-31 Given a node with children to load When expanded Then onExpand loads them first; collapsing moves the selection up":
    let roots = sampleTree()
    let t = newTreeView(roots)
    t.onExpand = proc(n: TreeNode) =
      if n.text == "lib" and n.children.len == 0: n.add newTreeNode("x.nim")
    t.expand(roots[0])
    let lib = roots[0].children[1]
    t.expand(lib)
    check lib.expanded and t.visibleNodes.len == 5
    t.select(lib.children[0])
    t.collapse(roots[0])
    check t.selected == roots[0]
    let empty = newTreeNode("empty", hasChildren = true)
    t.expand(empty)
    check not empty.expanded and not empty.canExpand

  test "TC-W-32 Given a focused tree When Right, Left, Space, Enter and clicks come Then it opens, walks, closes and activates":
    let roots = sampleTree()
    let t = newTreeView(roots)
    var activated: seq[string]
    t.onActivate = proc(n: TreeNode) = activated.add n.text
    let app = newApp(vbox(t.widget))
    app.resize(12, 5)
    discard app.draw()
    app.feed(key(kRight), 0)
    check roots[0].expanded
    app.feed(key(kRight), 0)
    check t.selected.text == "a.nim"
    app.feed(key(kLeft), 0)
    check t.selected.text == "src"
    app.feed(key(' '), 0)
    check not roots[0].expanded
    app.feed(key(kEnter), 0)
    discard app.draw()
    app.click(0, 0)                          # 印を押す: 開く
    check roots[0].expanded
    discard app.draw()
    app.click(5, 1, 100)
    app.click(5, 1, 200)
    check activated == @["src", "a.nim"]

suite "tableview":
  proc sampleTable(): TableView =
    result = newTableView([column("Name", natural()), column("Size", fixed(6), alRight), column("Note")])
    result.setRows(@[@["b.txt", "20", "x"], @["a.txt", "3", "y"], @["c.txt", "100", "z"]])

  test "TC-W-33 Given a table When drawn Then the header and rows are drawn in columns, aligned and fitted":
    let t = sampleTable()
    let app = newApp(vbox(t.widget))
    app.resize(22, 4)
    check app.shot == @["Name     Size Note    ", "b.txt      20 x       ", "a.txt       3 y       ",
                        "c.txt     100 z       "]

  test "TC-W-34 Given a table When sorted by a column Then rows are ordered, the header shows the direction, and the selected row stays selected":
    let t = sampleTable()
    let app = newApp(vbox(t.widget))
    app.resize(22, 4)
    t.select(2)                              # c.txt
    t.sortBy(0, sdAscending)
    check t.rows[0][0] == "a.txt" and t.cell(t.selected, 0) == "c.txt"
    check app.shot[0].startsWith("Name ▲")
    t.sortBy(0, sdDescending)
    check t.rows[0][0] == "c.txt" and t.selected == 0

  test "TC-W-35 Given a focused table When keys and clicks come Then rows are selected and activated, and a header click sorts and then reverses":
    let t = sampleTable()
    var activated: seq[int]
    t.onActivate = proc(r: int) = activated.add r
    let app = newApp(vbox(t.widget))
    app.resize(22, 4)
    discard app.draw()
    app.feed(key(kDown), 0)
    app.feed(key(kEnter), 0)
    check activated == @[1]
    app.click(1, 0)
    check t.sortedBy == (column: 0, direction: sdAscending)
    discard app.draw()
    app.click(1, 0)
    check t.sortedBy == (column: 0, direction: sdDescending)
    discard app.draw()
    app.click(1, 3, 100)
    app.click(1, 3, 200)
    check t.selected == 2 and activated == @[1, 2]
