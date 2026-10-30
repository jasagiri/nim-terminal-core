## 画面の上に開く、題と中身とボタンの窓。規則は ADR-TC-0002 の W-20〜W-22。

import nim_unicode_width
import ../[geometry, canvas, theme, event, widget, app]
import ./[label, button]

type
  Dialog* = ref object
    widget: Widget
    title*: string
    body: Widget
    buttonRow: Widget
    buttons: seq[Button]
    shownIn: App
    onClose*: proc(choice: int) {.closure, raises: [].}
      ## 押したボタンの番号。Esc で閉じたときは -1

const Cancelled* = -1

proc widget*(d: Dialog): Widget {.raises: [].} = d.widget
proc buttons*(d: Dialog): seq[Button] {.raises: [].} = d.buttons
proc isShown*(d: Dialog): bool {.raises: [].} = not d.shownIn.isNil and d.shownIn.isOpen(d.widget)

proc close*(d: Dialog, choice: int) {.raises: [].} =
  ## W-21: 層を閉じ (前のフォーカスに戻る。E-8)、onClose を呼ぶ。開いていなければ何もしない。
  if not d.isShown: return
  d.shownIn.closeLayer(d.widget)
  d.shownIn = nil
  if not d.onClose.isNil: d.onClose(choice)

proc setContent*(d: Dialog, content: Widget) {.raises: [].} =
  ## 中身を content に替える。
  let at = d.widget.children.find(d.body)
  d.body.remove()
  d.body = content
  d.widget.insert(content, max(at, 0))

proc newDialog*(title: string, message = "", buttons: openArray[string] = ["OK"]): Dialog {.raises: [].} =
  ## W-20: 枠を描き、上の辺に題を、内に中身 (既定は折り返す message) を、下にボタンを右寄せで並べる。
  ## 大きさは中身とボタンと題が測った大きさ (画面より大きければ画面に収める)。
  let d = Dialog(title: title)
  d.body = newLabel(message, wrap = true).widget
  d.body.constraint = fill()
  d.buttonRow = hbox(newWidget())          # 先頭の空きでボタンを右へ寄せる
  d.buttonRow.gap = 1
  d.buttonRow.constraint = fixed(1)
  proc closer(index: int): proc() {.closure, raises: [].} =
    # Why a factory: ループの中の let を閉包が捕まえると、全部が最後の値を共有する
    result = proc() = d.close(index)
  for i, text in buttons:
    let b = newButton(text, closer(i))
    d.buttons.add b
    d.buttonRow.add b.widget
  d.widget = vbox(d.body, d.buttonRow).padded(edges(1, 2)).gapped(1)
  d.widget.behavior.render = proc(c: Canvas, theme: Theme, focused: bool) =
    c.box(rect(0, 0, c.width, c.height), theme.border, theme[roNormal], d.title, theme[roTitle])
  d.widget.behavior.handle = proc(e: Event): bool =
    if e.isKey(kEscape):                   # W-21
      d.close(Cancelled)
      return true
    if e.kind == evKey and e.key.mods == {} and e.key.kind in {kLeft, kRight}:   # W-22: ボタンの間を動く
      if d.shownIn.isNil: return false
      let f = d.shownIn.focused
      for i, b in d.buttons:
        if b.widget == f:
          let j = (if e.key.kind == kLeft: i - 1 else: i + 1)
          if j >= 0 and j < d.buttons.len: discard d.shownIn.focus(d.buttons[j].widget)   # Why discard: 受けられるボタン
          return true
    false
  d.widget.behavior.measure = proc(available: Size, opts: WidthOptions): Size =
    let inner = size(available.width - 4, available.height - 2)
    let b = d.body.measure(inner, opts)
    var rowWidth = 0
    for btn in d.buttons: rowWidth += btn.widget.measure(inner, opts).width + 1
    let w = max(max(b.width, rowWidth), displayWidth(d.title, opts) + 4) + 4
    size(w, b.height + 1 + 1 + 2)
  d

proc show*(d: Dialog, app: App) {.raises: [].} =
  ## W-21: app の上に、画面の中央に開く (lmModal)。フォーカスは最初のボタン、中身に受けられるものが
  ## あればそれ (E-8)。
  if d.isShown: return
  d.shownIn = app
  let w = d.widget
  app.openLayer(w, proc(screen: Size): Rect =
    let m = w.measure(size(max(screen.width - 2, 0), max(screen.height - 2, 0)), app.widthOptions)
    centered(m.width, m.height)(screen))
