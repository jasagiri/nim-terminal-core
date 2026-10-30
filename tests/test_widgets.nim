## TC-W-*: Label・Button・Checkbox・TextInput・ListBox・ProgressBar。描いた画面を読み戻して確かめる。

import std/[unittest, unicode, options]
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
proc typeText(app: App, s: string) =
  for r in s.runes: app.feed(KeyEvent(kind: kRune, rune: r), 0)

suite "label":
  test "TC-W-1 Given lines and alignments When drawn Then each line is placed by the alignment, and a long line is cut with an ellipsis":
    let a = newLabel("left\n右")
    let b = newLabel("mid", align = alCenter)
    let c = newLabel("end", align = alRight)
    let d = newLabel("a line that is too long")
    let app = newApp(vbox(a.widget, b.widget, c.widget, d.widget))
    app.resize(9, 5)
    check app.shot == @["left     ", "右       ", "   mid   ", "      end", "a line t…"]

  test "TC-W-1 Given wrapping When drawn Then a long line folds at cluster boundaries":
    let l = newLabel("東京都庁ab", wrap = true)
    let app = newApp(vbox(l.widget))
    app.resize(5, 3)
    check app.shot == @["東京 ", "都庁a", "b    "]

  test "TC-W-2 Given a label When measured Then the longest line and the line count, wrapped when asked":
    check newLabel("ab\n東京都").widget.measure(size(80, 24)) == size(6, 2)
    check newLabel("abcdef", wrap = true).widget.measure(size(4, 24)) == size(4, 2)

  test "TC-W-1 Given a label bound to an observable When the value changes Then the label shows it":
    let count = observable(0)
    let l = newLabel()
    l.bindText(count.map(proc(n: int): string = $n & " files"))
    let app = newApp(vbox(l.widget))
    app.resize(10, 1)
    count.set(3)
    check app.shot == @["3 files   "]

suite "button":
  test "TC-W-3 Given buttons When drawn Then [ text ] is shown and the focused one uses the focused style":
    let ok = newButton("OK")
    let cancel = newButton("取消")
    let app = newApp(hbox(ok.widget, cancel.widget).gapped(1))
    app.resize(16, 1)
    let s = app.draw()
    check s.rows == @["[ OK ] [ 取消 ] "]   # 取消 は 4 列 (続きのセルの cellText は "")
    check s.screen.styleAt(0, 0) == app.theme[roFocused] and s.screen.styleAt(7, 0) == app.theme[roNormal]

  test "TC-W-4 Given a button When Enter, Space or a click comes Then onClick runs; a press released outside does not":
    var n = 0
    let b = newButton("Go", proc() = inc n)
    let app = newApp(vbox(b.widget.sized(fixed(1)), newWidget()))
    app.resize(10, 3)
    discard app.draw()
    app.feed(key(kEnter), 0)
    app.feed(key(' '), 0)
    app.click(1, 0)
    check n == 3
    app.feed(mouse(maPress, 1, 0), 0)
    check b.isPressed
    check app.draw().screen.styleAt(1, 0) == app.theme[roAccent]
    app.feed(mouse(maRelease, 1, 2), 0)
    check n == 3 and not b.isPressed

suite "checkbox":
  test "TC-W-5 Given a checkbox When Space, Enter or a click comes Then it toggles and shows the mark":
    let c = newCheckbox("通知")
    let app = newApp(vbox(c.widget))
    app.resize(10, 1)
    check app.shot == @["[ ] 通知  "]
    app.feed(key(' '), 0)
    check c.isChecked and app.shot == @["[x] 通知  "]
    app.feed(key(kEnter), 0)
    app.click(5, 0)
    check c.isChecked

  test "TC-W-6 Given a checkbox bound to an observable When either changes Then the other follows, and onChange runs only on change":
    let flag = observable(false)
    let c = newCheckbox("x")
    var told: seq[bool]
    c.onChange = proc(v: bool) = told.add v
    c.bindChecked(flag)
    c.toggle()
    check flag.value
    flag.set(false)
    check not c.isChecked
    c.setChecked(false)
    check told == @[true, false]

suite "textinput":
  test "TC-W-7 Given an empty input with a placeholder When drawn Then the placeholder is muted, and the cursor is at the start when focused":
    let t = newTextInput(placeholder = "検索")
    let app = newApp(vbox(t.widget))
    app.resize(8, 1)
    let s = app.draw()
    check s.rows == @["検索    "]
    check s.screen.styleAt(0, 0) == app.theme[roMuted]
    check s.cursor == some((x: 0, y: 0))

  test "TC-W-8 Given text longer than the field When typed Then the field scrolls so the cursor stays visible, and Home scrolls back":
    let t = newTextInput()
    let app = newApp(vbox(t.widget))
    app.resize(5, 1)
    app.typeText("abcdefgh")
    let s = app.draw()
    check s.rows == @["efgh "] and s.cursor == some((x: 4, y: 0))
    app.feed(key(kHome), 0)
    let h = app.draw()
    check h.rows == @["abcde"] and h.cursor == some((x: 0, y: 0))

  test "TC-W-8 Given wide characters cut at the field's edge When drawn Then the cut half is a space":
    let t = newTextInput("あいうえ")
    let app = newApp(vbox(t.widget))
    app.resize(4, 1)
    app.feed(key(kHome), 0)
    app.feed(key(kRight), 0)
    check app.shot == @["あい"]
    app.feed(key(kEnd), 0)
    check app.shot == @[" え "]      # い の右半分が見える所で空白になる

  test "TC-W-9 Given an input When keys, a paste, Enter and a click come Then it edits, submits and moves the cursor to the click":
    let t = newTextInput()
    var changes, submitted: seq[string]
    t.onChange = proc(v: string) = changes.add v
    t.onSubmit = proc(v: string) = submitted.add v
    let app = newApp(vbox(t.widget))
    app.resize(10, 1)
    app.typeText("東京")
    app.feed(KeyEvent(kind: kPaste, text: "都\n庁"), 0)
    check t.text == "東京都 庁"
    app.feed(key('w', {mCtrl}), 0)
    check t.text == "東京都 "
    app.feed(key(kEnter), 0)
    check submitted == @["東京都 "] and changes[^1] == "東京都 "
    discard app.draw()                # マウスは前に描いた画面に当たる
    app.click(3, 0)                   # 京 の右半分
    check app.draw().cursor == some((x: 4, y: 0))

  test "TC-W-7 Given a masked input When drawn Then each cluster shows the mask":
    let t = newTextInput("pass東")
    t.mask = some("*")
    let app = newApp(vbox(t.widget))
    app.resize(8, 1)
    check app.shot == @["*****   "]

suite "listbox":
  proc names(n: int): seq[ListItem] =
    for i in 0 ..< n: result.add item("item " & $i)

  test "TC-W-10 Given items When set Then the first is selected, and an empty list selects nothing":
    let l = newListBox(names(3))
    check l.selected == 0
    l.setItems(@[])
    check l.selected == -1
    l.setItems(names(5), 9)
    check l.selected == 4

  test "TC-W-11 Given more items than rows When the selection moves past the edge Then the view follows it":
    let l = newListBox(names(10))
    let app = newApp(vbox(l.widget))
    app.resize(8, 3)
    discard app.draw()
    for _ in 0 ..< 4: app.feed(key(kDown), 0)
    check l.selected == 4 and app.shot == @["item 2  ", "item 3  ", "item 4  "]
    app.feed(key(kPageUp), 0)
    check l.selected == 1 and app.shot[0] == "item 1  "
    app.feed(key(kEnd), 0)
    check l.selected == 9 and app.shot[2] == "item 9  "

  test "TC-W-12 Given a selected item with highlighted spans and a tab When drawn Then the row is selected to the edge, spans are emphasized, and the tab is expanded":
    let l = newListBox(@[item("a\tb", @[2 .. 2]), item("東京", @[0 .. 2])])
    let app = newApp(vbox(l.widget))
    app.resize(12, 2)
    let s = app.draw()
    check s.rows == @["a       b   ", "東京        "]
    check s.screen.styleAt(11, 0).reverse                       # 選んだ行は右の端まで
    check s.screen.styleAt(8, 0).bold and s.screen.styleAt(8, 0).reverse
    check s.screen.styleAt(0, 1).bold and not s.screen.styleAt(2, 1).bold
    l.widget.focusable = false                                  # フォーカスが無い: roSelectedInactive
    check app.draw().screen.styleAt(0, 0) == app.theme[roSelectedInactive]

  test "TC-W-13 Given a list When clicked, double clicked, wheeled and Enter pressed Then it selects, activates and scrolls":
    let l = newListBox(names(20))
    var selected, activated: seq[int]
    l.onSelect = proc(i: int) = selected.add i
    l.onActivate = proc(i: int) = activated.add i
    let app = newApp(vbox(l.widget))
    app.resize(8, 4)
    discard app.draw()
    app.click(0, 2, 1000)
    app.click(0, 2, 1100)
    check selected == @[2] and activated == @[2]
    app.feed(mouse(maWheelDown, 0, 0, mbNone), 0)
    check l.top == 3 and l.selected == 2
    discard app.draw()
    app.feed(key(kEnter), 0)
    check activated == @[2, 2]

suite "progressbar":
  test "TC-W-14 Given totals and counts When the fraction is asked Then it is clamped to 0..1, and 0 without a total":
    let p = newProgressBar(10, 0)
    p.update(5, 0)
    check p.fraction == 0.5
    p.update(20, 0)
    check p.fraction == 1.0
    p.setTotal(0)
    check p.fraction == 0.0

  test "TC-W-15 Given progress over time When the remaining time is asked Then it follows the average rate, and none before any progress":
    let p = newProgressBar(100, 1000)
    check p.etaMs.isNone
    p.update(25, 6000)                 # 5 秒で 25
    check p.etaMs == some(15000'i64)
    check formatDuration(15000) == "15s" and formatDuration(185_000) == "3m05s" and formatDuration(7_380_000) == "2h03m"

  test "TC-W-16 Given a bar When drawn Then the title, the filled cells, the percent and the ETA are shown":
    let p = newProgressBar(4, 0, "取込")
    p.update(1, 2000)
    let app = newApp(vbox(p.widget))
    app.resize(30, 1)
    check app.shot == @["取込 [██░░░░░░░░░]  25% ETA 6s"]   # 棒の内は 30 - 5 - 12 - 2 = 11 列
    p.setTotal(0)
    check app.shot[0].strip == "取込 1"
