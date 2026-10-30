## 1 行の編集。カーソルは書記素クラスタの境にあり、日本語や絵文字の 1 文字を 1 歩で動く。I/O を持たない。
## TextInput と、シェルの行編集 (nim-shell-lang) が使う。規則は ADR-TC-0002 の T-1〜T-6。

import std/unicode
import nim_unicode_width
import nim_terminal_io/keys

type
  LineEdit* = object
    text: string
    cursor: int          # バイトの位置 (クラスタの境)

  EditResult* = enum
    erIgnored            ## このキーは編集のものではない
    erMoved              ## カーソルだけが動いた
    erChanged            ## 文字が変わった

proc text*(e: LineEdit): string {.raises: [].} = e.text
proc cursor*(e: LineEdit): int {.raises: [].} = e.cursor   ## バイトの位置

proc sanitize(s: string): string =
  ## T-2: 1 行に入れられない文字 (改行・タブ) は空白にし、ほかの制御文字は捨てる
  for r in s.runes:
    if r == Rune('\n') or r == Rune('\r') or r == Rune('\t'): result.add ' '
    elif int(r) < 0x20 or int(r) == 0x7f or (int(r) >= 0x80 and int(r) < 0xa0): discard
    else: result.add r

proc initLineEdit*(text = ""): LineEdit {.raises: [].} =
  let t = sanitize(text)
  LineEdit(text: t, cursor: t.len)

proc setText*(e: var LineEdit, text: string) {.raises: [].} =
  ## 文字を置き換え、カーソルを末尾へ。
  e.text = sanitize(text)
  e.cursor = e.text.len

proc boundaries(s: string): seq[int] =
  ## クラスタの境のバイトの位置 (0 と末尾を含む)
  result.add 0
  for c in clusters(s): result.add c.bytes.b + 1

proc previous(s: string, at: int): int =
  result = 0
  for b in boundaries(s):
    if b < at: result = b

proc next(s: string, at: int): int =
  for b in boundaries(s):
    if b > at: return b
  s.len

proc column*(e: LineEdit, opts = WidthOptions()): int {.raises: [].} =
  ## カーソルの前の文字の幅 (画面の列)。
  displayWidth(e.text[0 ..< e.cursor], opts)

proc setColumn*(e: var LineEdit, col: int, opts = WidthOptions()) {.raises: [].} =
  ## T-5: 画面の列 col に一番近いクラスタの境へカーソルを動かす (幅 2 の文字の右半分なら、その後ろ)。
  var used = 0
  e.cursor = 0
  for c in clusters(e.text, opts):
    if used + (c.width + 1) div 2 > col: return
    used += c.width
    e.cursor = c.bytes.b + 1

proc insert*(e: var LineEdit, s: string) {.raises: [].} =
  ## T-2: カーソルの所に入れ、カーソルを入れた後ろへ。
  let t = sanitize(s)
  e.text = e.text[0 ..< e.cursor] & t & e.text[e.cursor .. ^1]
  e.cursor += t.len
  # 入れた文字が前のクラスタとつながる (結合文字) と、境が変わる。境に寄せる
  if e.cursor notin boundaries(e.text): e.cursor = next(e.text, e.cursor)

proc moveLeft*(e: var LineEdit) {.raises: [].} = e.cursor = previous(e.text, e.cursor)
proc moveRight*(e: var LineEdit) {.raises: [].} = e.cursor = next(e.text, e.cursor)
proc moveHome*(e: var LineEdit) {.raises: [].} = e.cursor = 0
proc moveEnd*(e: var LineEdit) {.raises: [].} = e.cursor = e.text.len

proc isSpaceAt(s: string, at: int): bool =
  at < s.len and s.runeAt(at).isWhiteSpace

proc wordStart(e: LineEdit): int =
  ## カーソルの前の空白を飛ばし、その前の語の頭
  result = e.cursor
  while result > 0 and isSpaceAt(e.text, previous(e.text, result)): result = previous(e.text, result)
  while result > 0 and not isSpaceAt(e.text, previous(e.text, result)): result = previous(e.text, result)

proc wordEnd(e: LineEdit): int =
  result = e.cursor
  while result < e.text.len and isSpaceAt(e.text, result): result = next(e.text, result)
  while result < e.text.len and not isSpaceAt(e.text, result): result = next(e.text, result)

proc moveWordLeft*(e: var LineEdit) {.raises: [].} = e.cursor = e.wordStart
proc moveWordRight*(e: var LineEdit) {.raises: [].} = e.cursor = e.wordEnd

proc cut(e: var LineEdit, a, b: int): string =
  result = e.text[a ..< b]
  e.text = e.text[0 ..< a] & e.text[b .. ^1]
  e.cursor = a

proc deleteBackward*(e: var LineEdit): bool {.raises: [].} =
  ## カーソルの前の 1 クラスタを消す。消したら true。
  if e.cursor == 0: return false
  discard e.cut(previous(e.text, e.cursor), e.cursor)   # Why discard: 消した文字は返さない (kill ではない)
  true

proc deleteForward*(e: var LineEdit): bool {.raises: [].} =
  if e.cursor >= e.text.len: return false
  discard e.cut(e.cursor, next(e.text, e.cursor))       # Why discard: 同上
  true

proc killToEnd*(e: var LineEdit): string {.raises: [].} = e.cut(e.cursor, e.text.len)
proc killToStart*(e: var LineEdit): string {.raises: [].} = e.cut(0, e.cursor)
proc killWordBackward*(e: var LineEdit): string {.raises: [].} = e.cut(e.wordStart, e.cursor)

proc apply*(e: var LineEdit, k: KeyEvent): EditResult {.raises: [].} =
  ## T-3: 文字・貼り付け・矢印・Home・End・Backspace・Delete と、Emacs の Ctrl・Alt のキー
  ## (C-a C-e C-b C-f C-h C-d C-k C-u C-w、M-b M-f) で編集する。Enter・Tab・Esc などは erIgnored。
  let before = e.text
  let at = e.cursor
  case k.kind
  of kRune:
    if k.mods == {} or k.mods == {mShift}: e.insert($k.rune)
    elif int(k.rune) >= 0x80: return erIgnored
    elif k.mods == {mCtrl}:
      case char(int(k.rune))
      of 'a': e.moveHome()
      of 'e': e.moveEnd()
      of 'b': e.moveLeft()
      of 'f': e.moveRight()
      of 'h': discard e.deleteBackward()     # Why discard: 変わったかは下で比べる
      of 'd': discard e.deleteForward()      # Why discard: 同上
      of 'k': discard e.killToEnd()          # Why discard: 同上
      of 'u': discard e.killToStart()        # Why discard: 同上
      of 'w': discard e.killWordBackward()   # Why discard: 同上
      else: return erIgnored
    elif k.mods == {mAlt}:
      case char(int(k.rune))
      of 'b': e.moveWordLeft()
      of 'f': e.moveWordRight()
      else: return erIgnored
    else: return erIgnored
  of kPaste: e.insert(k.text)
  of kLeft:
    if mCtrl in k.mods or mAlt in k.mods: e.moveWordLeft() else: e.moveLeft()
  of kRight:
    if mCtrl in k.mods or mAlt in k.mods: e.moveWordRight() else: e.moveRight()
  of kHome: e.moveHome()
  of kEnd: e.moveEnd()
  of kBackspace: discard e.deleteBackward()  # Why discard: 同上
  of kDelete: discard e.deleteForward()      # Why discard: 同上
  else: return erIgnored
  if e.text != before: erChanged
  elif e.cursor != at: erMoved
  else: erMoved      # 端で動けなかった矢印も、編集のキーとして扱った
