## TC-T-*: 1 行の編集 (書記素クラスタ単位)。

import std/[unittest, unicode]
import nim_unicode_width
import nim_terminal_core/lineedit
import nim_terminal_io/keys

proc key(c: char, mods: set[KeyMod] = {}): KeyEvent = KeyEvent(kind: kRune, rune: Rune(ord(c)), mods: mods)
proc key(k: KeyKind, mods: set[KeyMod] = {}): KeyEvent = KeyEvent(kind: k, mods: mods)
proc typed(s: string): seq[KeyEvent] =
  for r in s.runes: result.add KeyEvent(kind: kRune, rune: r)

suite "lineedit":
  test "TC-T-1 Given text with wide, joined and combining characters When the cursor moves Then each step is one grapheme cluster":
    var e = initLineEdit("a東👨‍👩‍👧éb")
    check e.cursor == e.text.len
    var steps: seq[int]
    while e.cursor > 0:
      e.moveLeft()
      steps.add e.cursor
    check steps.len == 5                    # b、é、家族、東、a
    e.moveRight()
    e.moveRight()
    check e.text[0 ..< e.cursor] == "a東"

  test "TC-T-2 Given text with line breaks, tabs and control characters When inserted Then breaks and tabs become spaces and the rest are dropped":
    var e = initLineEdit()
    e.insert("a\nb\tc\r\x07d\x7f\u0085e")
    check e.text == "a b c de"
    var j = initLineEdit("e")
    j.insert("́")                      # 結合文字は前の文字とつながり、カーソルは境に留まる
    check j.text == "é" and j.cursor == j.text.len
    check initLineEdit("x\ny").text == "x y"

  test "TC-T-3 Given keys When applied Then characters insert, Emacs and arrow keys edit, and Enter, Tab and Esc are left to the caller":
    var e = initLineEdit()
    for k in typed("hello"): check e.apply(k) == erChanged
    check e.apply(key('a', {mCtrl})) == erMoved and e.cursor == 0
    check e.apply(key('d', {mCtrl})) == erChanged and e.text == "ello"
    check e.apply(key('e', {mCtrl})) == erMoved
    check e.apply(key(kBackspace)) == erChanged and e.text == "ell"
    check e.apply(key('b', {mCtrl})) == erMoved and e.apply(key(kLeft)) == erMoved and e.cursor == 1
    check e.apply(key(kDelete)) == erChanged and e.text == "el"
    check e.apply(key(kHome)) == erMoved and e.apply(key('h', {mCtrl})) == erMoved   # 先頭で消す物が無い
    check e.apply(KeyEvent(kind: kPaste, text: "x\ny")) == erChanged and e.text == "x yel"
    check e.apply(key(kEnter)) == erIgnored and e.apply(key(kTab)) == erIgnored and e.apply(key(kEscape)) == erIgnored
    check e.apply(key('z', {mCtrl})) == erIgnored and e.apply(KeyEvent(kind: kRune, rune: "あ".runeAt(0), mods: {mCtrl})) == erIgnored

  test "TC-T-4 Given words When killed and moved by word Then whitespace separates words":
    var e = initLineEdit("cd  東京 都庁")
    check e.killWordBackward() == "都庁"
    check e.text == "cd  東京 "
    discard e.apply(key('b', {mAlt}))
    check e.text[e.cursor .. ^1] == "東京 "
    discard e.apply(key('f', {mAlt}))
    check e.text[0 ..< e.cursor] == "cd  東京"
    check e.killToEnd() == " " and e.killToStart() == "cd  東京" and e.text == ""
    var w = initLineEdit("one two")
    check w.apply(key('w', {mCtrl})) == erChanged and w.text == "one "
    discard w.apply(key(kLeft, {mCtrl}))
    check w.cursor == 0

  test "TC-T-5 Given a screen column When the cursor is set there Then it goes to the nearest cluster boundary":
    var e = initLineEdit("a東京b")       # 列: a=0、東=1〜2、京=3〜4、b=5
    e.setColumn(0)
    check e.cursor == 0
    e.setColumn(1)
    check e.text[0 ..< e.cursor] == "a"
    e.setColumn(2)                        # 東 の右半分 → 東 の後ろ
    check e.text[0 ..< e.cursor] == "a東"
    e.setColumn(99)
    check e.cursor == e.text.len

  test "TC-T-6 Given a cursor When its column is asked Then it is the display width before it":
    var e = initLineEdit("a東─")
    check e.column == 4
    check e.column(WidthOptions(ambiguousWide: true)) == 5
    e.moveLeft()
    check e.column == 3
