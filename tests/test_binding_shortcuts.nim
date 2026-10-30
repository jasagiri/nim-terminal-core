## TC-B-*: 値の変化の知らせ。TC-K-*: キーの組み合わせと文脈。

import std/[unittest, unicode, strutils]
import nim_outcome
import nim_terminal_core/[binding, shortcuts]
import nim_terminal_io/keys

proc key(c: char, mods: set[KeyMod] = {}): KeyEvent = KeyEvent(kind: kRune, rune: Rune(ord(c)), mods: mods)

suite "binding":
  test "TC-B-1 Given two subscribers When the value changes Then both get the new value in order, and setting the same value tells no one":
    let o = observable(1)
    var seen: seq[string]
    discard o.subscribe(proc(v: int) = seen.add "a" & $v)
    discard o.subscribe(proc(v: int) = seen.add "b" & $v)
    o.set(2)
    o.value = 2
    o.value = 3
    check seen == @["a2", "b2", "a3", "b3"]
    check o.value == 3

  test "TC-B-2 Given a subscriber removed, even during a notification Then it is not called afterwards":
    let o = observable("")
    var calls: seq[string]
    var second: Subscription
    discard o.subscribe(proc(v: string) =
      calls.add "first " & v
      o.unsubscribe(second))
    second = o.subscribe(proc(v: string) = calls.add "second " & v)
    o.set("x")
    o.set("y")
    check calls == @["first x", "first y"]

  test "TC-B-3 Given a mapped observable When the source changes Then the mapped value follows":
    let count = observable(0)
    let label = count.map(proc(n: int): string = $n & " items")
    check label.value == "0 items"
    var told: seq[string]
    discard label.subscribe(proc(v: string) = told.add v)
    count.set(3)
    check label.value == "3 items" and told == @["3 items"]

  test "TC-B-4 Given two observables bound both ways When one changes Then both settle without looping":
    let a = observable(0)
    let b = observable(0)
    var calls = 0
    discard a.subscribe(proc(v: int) =
      inc calls
      b.set(v))
    discard b.subscribe(proc(v: int) =
      inc calls
      a.set(v))
    a.set(5)
    check a.value == 5 and b.value == 5 and calls == 2

suite "shortcuts":
  test "TC-K-1 Given key specs When parsed Then modifiers and names are read regardless of case, and bad specs fail with a reason":
    check parseChord("ctrl+s").get == Chord(kind: kRune, rune: Rune('s'), mods: {mCtrl})
    check parseChord("Ctrl+S").get == Chord(kind: kRune, rune: Rune('s'), mods: {mCtrl})
    check parseChord("shift+tab").get == Chord(kind: kTab, mods: {mShift})
    check parseChord("alt+x").get == Chord(kind: kRune, rune: Rune('x'), mods: {mAlt})
    check parseChord("shift+a").get == Chord(kind: kRune, rune: Rune('A'))
    check parseChord("PageDown").get == Chord(kind: kPageDown)
    check parseChord("space").get == Chord(kind: kRune, rune: Rune(' '))
    check parseChord("plus").get.rune == Rune('+')
    check parseChord("?").get == Chord(kind: kRune, rune: Rune('?'))
    check parseChord("あ").get.rune == "あ".runeAt(0)
    check parseChord("hyper+x").isFailure and "hyper" in parseChord("hyper+x").error
    check parseChord("ctrl+shift+a").isFailure
    check parseChord("nosuchkey").isFailure
    check parseChord("ctrl+").isFailure

  test "TC-K-2 Given chords When shown Then the display form is used":
    check $parseChord("ctrl+s").get == "Ctrl+S"
    check $parseChord("alt+x").get == "Alt+x"
    check $parseChord("shift+tab").get == "Shift+Tab"
    check $parseChord("esc").get == "Esc"
    check $parseChord("pageup").get == "PageUp"
    check $parseChord("space").get == "Space"
    check $parseChord("q").get == "q"

  test "TC-K-3 Given chords When matched against keys Then the kind and modifiers must agree, and Ctrl letters ignore case":
    let ctrlS = parseChord("ctrl+s").get
    check ctrlS.matches(key('s', {mCtrl})) and ctrlS.matches(key('S', {mCtrl}))
    check not ctrlS.matches(key('s')) and not ctrlS.matches(key('s', {mCtrl, mAlt}))
    let q = parseChord("q").get
    check q.matches(key('q')) and not q.matches(key('Q'))
    check parseChord("alt+X").get.matches(key('X', {mAlt})) and not parseChord("alt+x").get.matches(key('X', {mAlt}))
    check parseChord("shift+tab").get.matches(KeyEvent(kind: kTab, mods: {mShift}))

  test "TC-K-4 Given contexts pushed on global When a key is pressed Then the top context wins, and popping it restores global":
    let s = newShortcuts()
    var ran: seq[string]
    check s.add("q", "quit", proc() = ran.add "global q").isOk
    check s.add("q", "close the dialog", (proc() = ran.add "dialog q"), "dialog").isOk
    check s.add("x", "other", (proc() = ran.add "editor x"), "editor").isOk
    check s.handle(key('q'))
    s.push("dialog")
    check s.handle(key('q'))
    check not s.handle(key('x'))          # editor は積んでいない
    s.pop()
    check s.handle(key('q'))
    s.pop()                              # 積んでいなくても何もしない
    check not s.handle(key('z'))
    check ran == @["global q", "dialog q", "global q"]

  test "TC-K-5 Given a chord already bound in a context When bound again there Then it fails, and removing it frees it":
    let s = newShortcuts()
    check s.add("ctrl+s", "save", proc() = discard).isOk
    check s.add("Ctrl+S", "save again", proc() = discard).isFailure
    check s.add("ctrl+s", "save in the editor", (proc() = discard), "editor").isOk
    check s.remove("ctrl+s").isOk
    check s.remove("ctrl+s").isFailure
    check s.add("ctrl+s", "save", proc() = discard).isOk

  test "TC-K-6 Given a shadowed shortcut When the active ones are listed Then they come in precedence order without the shadowed one":
    let s = newShortcuts()
    check s.add("q", "quit", proc() = discard).isOk
    check s.add("?", "help", proc() = discard).isOk
    check s.add("q", "close", (proc() = discard), "dialog").isOk
    s.push("dialog")
    var listed: seq[string]
    for e in s.active: listed.add $e.chord & " " & e.description
    check listed == @["q close", "? help"]
