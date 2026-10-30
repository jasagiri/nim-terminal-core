## キーの組み合わせと動作の対応。文脈 (画面や場面) を積み、上の文脈から探す。規則は ADR-TC-0001 の K-1〜K-6。

import std/[unicode, strutils]
import nim_outcome
import nim_terminal_io/keys

type
  Chord* = object
    ## キーの組み合わせ。kRune の Ctrl つきの文字は小文字で持つ (端末は Ctrl+A と Ctrl+Shift+A を区別しない)
    kind*: KeyKind
    rune*: Rune
    mods*: set[KeyMod]

  Shortcut* = object
    chord*: Chord
    description*: string
    context*: string
    action: proc() {.closure, raises: [].}

  Shortcuts* = ref object
    entries: seq[Shortcut]
    contexts: seq[string]    # 積んだ文脈。"global" はいつも一番下

const Global* = "global"

const KeyNames = [("enter", kEnter), ("tab", kTab), ("backspace", kBackspace), ("esc", kEscape),
                  ("escape", kEscape), ("up", kUp), ("down", kDown), ("left", kLeft), ("right", kRight),
                  ("home", kHome), ("end", kEnd), ("pageup", kPageUp), ("pagedown", kPageDown),
                  ("insert", kInsert), ("delete", kDelete)]

proc parseChord*(spec: string): Outcome[Chord] {.raises: [].} =
  ## K-1: "ctrl+s"、"alt+x"、"shift+tab"、"enter"、"q"、"space"、"?" の形。修飾と名前は大小を問わない。
  ## "+" そのものは "plus"。
  let parts = spec.strip.split('+')
  if parts.len == 0 or parts[^1].len == 0: return failure[Chord]("an empty key: ", spec)
  var mods: set[KeyMod]
  for m in parts[0 ..< ^1]:
    case m.toLowerAscii
    of "ctrl", "control": mods.incl mCtrl
    of "alt", "meta": mods.incl mAlt
    of "shift": mods.incl mShift
    else: return failure[Chord]("an unknown modifier: ", m & " in " & spec)
  let name = parts[^1]
  for (n, k) in KeyNames:
    if name.toLowerAscii == n: return success(Chord(kind: k, mods: mods))
  var r: Rune
  case name.toLowerAscii
  of "space": r = Rune(' ')
  of "plus": r = Rune('+')
  else:
    if name.runeLen != 1: return failure[Chord]("an unknown key: ", name & " in " & spec)
    r = name.runeAt(0)
  if mShift in mods:
    if mCtrl in mods: return failure[Chord]("the terminal cannot tell Shift with Ctrl on a letter: ", spec)
    mods.excl mShift
    r = r.toUpper
  if mCtrl in mods: r = r.toLower
  success(Chord(kind: kRune, rune: r, mods: mods))

proc `$`*(c: Chord): string {.raises: [].} =
  ## K-2: 表示の形 ("Ctrl+S"、"Alt+X"、"Shift+Tab"、"Enter"、"q")。
  for (m, n) in [(mCtrl, "Ctrl+"), (mAlt, "Alt+"), (mShift, "Shift+")]:
    if m in c.mods: result.add n
  if c.kind == kRune:
    if c.rune == Rune(' '): result.add "Space"
    elif mCtrl in c.mods: result.add $c.rune.toUpper
    else: result.add $c.rune
  else:
    for (n, k) in KeyNames:
      if k == c.kind:
        result.add(if n == "esc": "Esc" elif n == "pageup": "PageUp" elif n == "pagedown": "PageDown"
                   else: n.capitalizeAscii)
        break

proc matches*(c: Chord, k: KeyEvent): bool {.raises: [].} =
  ## K-3: 同じキーで同じ修飾。Ctrl つきの文字は大小を問わない。
  if c.kind != k.kind or c.mods != k.mods: return false
  if c.kind != kRune: return true
  if mCtrl in c.mods: c.rune == k.rune.toLower
  else: c.rune == k.rune

proc newShortcuts*(): Shortcuts {.raises: [].} = Shortcuts()

proc add*(s: Shortcuts, spec, description: string, action: proc() {.closure, raises: [].},
          context = Global): Outcome[void] {.raises: [].} =
  ## K-5: 同じ文脈に同じ組み合わせを 2 度は足せない。
  let chord = ?parseChord(spec)
  for e in s.entries:
    if e.context == context and e.chord == chord:
      return failure[void]("the key is already bound in ", context & ": " & $chord)
  s.entries.add Shortcut(chord: chord, description: description, context: context, action: action)
  success()

proc remove*(s: Shortcuts, spec: string, context = Global): Outcome[void] {.raises: [].} =
  let chord = ?parseChord(spec)
  for i, e in s.entries:
    if e.context == context and e.chord == chord:
      s.entries.delete(i)
      return success()
  failure[void]("the key is not bound in ", context & ": " & $chord)

proc push*(s: Shortcuts, context: string) {.raises: [].} =
  ## 文脈を積む (その文脈の割り当てが、下の文脈より先に効く)。
  s.contexts.add context

proc pop*(s: Shortcuts) {.raises: [].} =
  ## 一番上の文脈を下ろす。積んでいなければ何もしない。
  if s.contexts.len > 0: s.contexts.setLen(s.contexts.len - 1)

proc order(s: Shortcuts): seq[string] =
  for i in countdown(s.contexts.high, 0): result.add s.contexts[i]
  result.add Global

proc active*(s: Shortcuts): seq[Shortcut] {.raises: [].} =
  ## K-6: 今効く割り当てを、効く順に。上の文脈に隠れたものは含めない (ヘルプの表示に使う)。
  for ctx in s.order:
    for e in s.entries:
      if e.context != ctx: continue
      var hidden = false
      for a in result:
        if a.chord == e.chord: hidden = true
      if not hidden: result.add e

proc handle*(s: Shortcuts, k: KeyEvent): bool {.raises: [].} =
  ## K-4: 積んだ文脈を上から、最後に global を探し、最初に当たったものを動かす。動かしたら true。
  for ctx in s.order:
    for e in s.entries:
      if e.context == ctx and e.chord.matches(k):
        e.action()
        return true
  false
