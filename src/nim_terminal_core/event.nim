## ウィジェットに届く事象。キーとマウスの解読は nim-terminal-io の keys。クリックとダブルクリックは
## 押す・離すから振り分けが作る (ADR-TC-0001 の E-6)。

import std/unicode
import nim_terminal_io/keys
export keys

type
  EventKind* = enum
    evKey           ## キー。key が中身
    evPaste         ## 貼り付け (bracketed paste)。text が中身
    evPress         ## ボタンを押した
    evRelease       ## ボタンを離した (押したウィジェットに届く)
    evDrag          ## 押したまま動かした (押したウィジェットに届く)
    evMove          ## ボタンを押さずに動かした
    evWheel         ## ホイール。wheel が向き
    evClick         ## 押して、同じウィジェットの上で離した
    evDoubleClick   ## 同じ所を続けて 2 度クリックした (2 度目の evClick の後に届く)
    evFocusIn       ## 入力を受けるようになった
    evFocusOut      ## 入力を受けなくなった

  Event* = object
    kind*: EventKind
    key*: KeyEvent
    text*: string
    x*, y*: int               ## マウス: 受け取るウィジェットの左上からの位置 (外のこともある)
    screenX*, screenY*: int   ## マウス: 画面の位置
    button*: MouseButton
    mods*: set[KeyMod]
    wheel*: MouseAction       ## evWheel: maWheelUp・maWheelDown・maWheelLeft・maWheelRight

proc isMouse*(e: Event): bool {.raises: [].} =
  e.kind in {evPress, evRelease, evDrag, evMove, evWheel, evClick, evDoubleClick}

proc isKey*(e: Event, kind: KeyKind): bool {.raises: [].} =
  ## 修飾の無いそのキーか。
  e.kind == evKey and e.key.kind == kind and e.key.mods == {}

proc isCtrl*(e: Event, letter: char): bool {.raises: [].} =
  ## Ctrl と英字 (小文字で渡す) か。
  e.kind == evKey and e.key.kind == kRune and e.key.mods == {mCtrl} and e.key.rune == Rune(ord(letter))
