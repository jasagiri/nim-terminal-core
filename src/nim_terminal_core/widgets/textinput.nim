## 1 行の入力欄。編集は lineedit (書記素クラスタ単位)。規則は ADR-TC-0002 の T-1〜T-6 と W-7〜W-9。

import std/options
import nim_unicode_width
import ../[geometry, canvas, theme, event, widget, binding, lineedit]

export lineedit

type
  TextInput* = ref object
    widget: Widget
    edit: LineEdit
    scroll: int          # 見えている最初の列
    placeholder*: string
    mask*: Option[string]    ## 伏せ字 (パスワード)。some なら各クラスタをこの字で描く
    onChange*: proc(text: string) {.closure, raises: [].}
    onSubmit*: proc(text: string) {.closure, raises: [].}

proc widget*(t: TextInput): Widget {.raises: [].} = t.widget
proc text*(t: TextInput): string {.raises: [].} = t.edit.text
proc lineEdit*(t: TextInput): LineEdit {.raises: [].} = t.edit

proc changed(t: TextInput) =
  if not t.onChange.isNil: t.onChange(t.edit.text)

proc setText*(t: TextInput, text: string) {.raises: [].} =
  ## 文字を置き換え、カーソルを末尾へ。変わったら onChange を呼ぶ。
  let before = t.edit.text
  t.edit.setText(text)
  if t.edit.text != before: t.changed()

proc apply*(t: TextInput, k: KeyEvent): EditResult {.raises: [].} =
  ## キーで編集する (フォーカスが無くても、呼び手が回したキーを受ける)。変わったら onChange を呼ぶ。
  result = t.edit.apply(k)
  if result == erChanged: t.changed()

proc shownText(t: TextInput): string =
  if t.mask.isNone: return t.edit.text
  for _ in clusters(t.edit.text): result.add t.mask.get

proc shownColumn(t: TextInput, opts: WidthOptions): int =
  if t.mask.isNone: return t.edit.column(opts)
  var n = 0
  for c in clusters(t.edit.text[0 ..< t.edit.cursor]): inc n
  n * displayWidth(t.mask.get, opts)

proc follow(t: TextInput, width: int, opts: WidthOptions) =
  ## W-8: カーソルが欄の中に見えるよう、見える最初の列を動かす
  let col = t.shownColumn(opts)
  if col < t.scroll: t.scroll = col
  if width > 0 and col >= t.scroll + width: t.scroll = col - width + 1
  let total = displayWidth(t.shownText, opts)
  t.scroll = max(0, min(t.scroll, max(0, total + 1 - width)))

proc newTextInput*(text = "", placeholder = ""): TextInput {.raises: [].} =
  ## W-7: 文字を描き、空なら placeholder を roMuted で描く。フォーカスがあれば端末のカーソルを
  ## カーソルの所に置く (日本語の入力の変換の窓がそこに出る)。
  ## W-8: 欄より長い文字は、カーソルが見えるよう横に送る。幅 2 の文字が欄の端で切れたら空白で描く (C-1)。
  ## W-9: キーは T-3 で編集し、Enter で onSubmit を呼ぶ。押した列にカーソルを動かす (T-5)。
  let t = TextInput(edit: initLineEdit(text), placeholder: placeholder)
  t.widget = newWidget(focusable = true)
  t.widget.constraint = fixed(1)
  t.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    let opts = c.widthOptions
    t.follow(c.width, opts)
    if t.edit.text.len == 0 and t.placeholder.len > 0:
      discard c.put(0, 0, c.fit(t.placeholder, c.width), theme[roMuted])   # Why discard: 収めた
    else:
      discard c.put(-t.scroll, 0, t.shownText, theme[roNormal])          # Why discard: 切り抜きが切る
    if focused: c.setCursor(t.shownColumn(opts) - t.scroll, 0)
  t.widget.behavior.handle = proc(e: Event): bool =
    case e.kind
    of evKey:
      if e.isKey(kEnter):
        if not t.onSubmit.isNil: t.onSubmit(t.edit.text)
        return true
      t.apply(e.key) != erIgnored
    of evPaste:
      discard t.apply(KeyEvent(kind: kPaste, text: e.text))   # Why discard: 貼り付けはいつも扱う
      true
    of evPress:
      if t.mask.isNone: t.edit.setColumn(e.x + t.scroll)
      true
    else: false
  t.widget.behavior.measure = proc(available: Size, opts: WidthOptions): Size =
    size(max(displayWidth(t.shownText, opts), displayWidth(t.placeholder, opts)) + 1, 1)
  t

proc bindText*(t: TextInput, source: Observable[string]) {.raises: [].} =
  ## source と両向きにつなぐ。
  t.edit.setText(source.value)
  discard source.subscribe(proc(v: string) =
    if v != t.edit.text: t.setText(v))   # Why discard: TextInput と同じだけ生きる
  let previous = t.onChange
  t.onChange = proc(v: string) =
    source.set(v)
    if not previous.isNil: previous(v)
