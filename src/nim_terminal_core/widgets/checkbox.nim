## 入・切を持つウィジェット。規則は ADR-TC-0002 の W-5〜W-6。

import std/unicode
import nim_unicode_width
import ../[geometry, canvas, theme, event, widget, binding]

type
  Checkbox* = ref object
    widget: Widget
    text: string
    checked: bool
    onChange*: proc(checked: bool) {.closure, raises: [].}

proc widget*(c: Checkbox): Widget {.raises: [].} = c.widget
proc text*(c: Checkbox): string {.raises: [].} = c.text
proc setText*(c: Checkbox, text: string) {.raises: [].} = c.text = text
proc isChecked*(c: Checkbox): bool {.raises: [].} = c.checked

proc setChecked*(c: Checkbox, checked: bool) {.raises: [].} =
  ## W-6: 変わったときだけ onChange を呼ぶ。
  if c.checked == checked: return
  c.checked = checked
  if not c.onChange.isNil: c.onChange(checked)

proc toggle*(c: Checkbox) {.raises: [].} = c.setChecked(not c.checked)

proc newCheckbox*(text: string, checked = false): Checkbox {.raises: [].} =
  ## W-5: `[x] text` か `[ ] text` と描き、フォーカスがあれば印の 3 列を roFocused にする。
  ## Space と Enter とクリックで入・切を替える。
  let cb = Checkbox(text: text, checked: checked)
  cb.widget = newWidget(focusable = true)
  cb.widget.constraint = natural()
  cb.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    let mark = if cb.checked: "[x]" else: "[ ]"
    let used = c.put(0, 0, mark, if focused: theme[roFocused] else: theme[roNormal])
    discard c.put(used, 0, c.fit(" " & cb.text, c.width - used), theme[roNormal])   # Why discard: 収めた
  cb.widget.behavior.handle = proc(e: Event): bool =
    if e.kind == evClick or e.isKey(kEnter) or
       (e.kind == evKey and e.key.kind == kRune and e.key.mods == {} and e.key.rune == Rune(' ')):
      cb.toggle()
      return true
    e.kind == evPress   # 押したことは、クリックになるまで受けておく
  cb.widget.behavior.measure = proc(available: Size, opts: WidthOptions): Size =
    size(displayWidth(cb.text, opts) + 4, 1)
  cb

proc bindChecked*(c: Checkbox, source: Observable[bool]) {.raises: [].} =
  ## W-6: source と両向きにつなぐ。どちらを変えても、もう片方が同じ値になる (B-4 で回り続けない)。
  c.checked = source.value
  discard source.subscribe(proc(v: bool) = c.setChecked(v))   # Why discard: Checkbox と同じだけ生きる
  let previous = c.onChange
  c.onChange = proc(v: bool) =
    source.set(v)
    if not previous.isNil: previous(v)
