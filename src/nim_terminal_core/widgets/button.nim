## 押すと動作するウィジェット。規則は ADR-TC-0002 の W-3〜W-4。

import std/unicode
import nim_unicode_width
import ../[geometry, canvas, theme, event, widget]

type
  Button* = ref object
    widget: Widget
    text: string
    pressed: bool
    onClick*: proc() {.closure, raises: [].}

proc widget*(b: Button): Widget {.raises: [].} = b.widget
proc text*(b: Button): string {.raises: [].} = b.text
proc setText*(b: Button, text: string) {.raises: [].} = b.text = text
proc isPressed*(b: Button): bool {.raises: [].} = b.pressed   ## マウスで押している間

proc click*(b: Button) {.raises: [].} =
  if not b.onClick.isNil: b.onClick()

proc newButton*(text: string, onClick: proc() {.closure, raises: [].} = nil): Button {.raises: [].} =
  ## W-3: `[ text ]` と描く。フォーカスがあれば roFocused、マウスで押している間は roAccent。
  ## W-4: フォーカスがあるときの Enter と Space、クリックで onClick を呼ぶ。押して外で離したら呼ばない。
  let b = Button(text: text, onClick: onClick)
  b.widget = newWidget(focusable = true)
  b.widget.constraint = natural()
  b.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    let style = if b.pressed: theme[roAccent] elif focused: theme[roFocused] else: theme[roNormal]
    discard c.put(0, 0, c.fit("[ " & b.text & " ]", c.width), style)   # Why discard: fit で収めた
  b.widget.behavior.handle = proc(e: Event): bool =
    case e.kind
    of evKey:
      if e.isKey(kEnter) or (e.key.kind == kRune and e.key.mods == {} and e.key.rune == Rune(' ')):
        b.click()
        return true
    of evPress:
      b.pressed = true
      return true
    of evRelease:
      b.pressed = false
      return true
    of evClick:
      b.click()
      return true
    of evFocusOut: b.pressed = false
    else: discard
    false
  b.widget.behavior.measure = proc(available: Size, opts: WidthOptions): Size =
    size(displayWidth(b.text, opts) + 4, 1)
  b
