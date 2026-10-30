## 入力の画面: メニューの帯、入力欄、チェックボックス、送るボタン、確かめのダイアログ、ショートカット。
## Ctrl+Q で終わる。名前を入れて「送る」を押すと、ダイアログで確かめる。

import nim_terminal_core

let app = newApp(newWidget())
let name = newTextInput(placeholder = "名前")
let notify = newCheckbox("知らせを受け取る")
let status = newLabel("", role = roMuted)
let summary = observable("")
discard summary.subscribe(proc(s: string) = status.setText(s))   # Why discard: アプリと同じだけ生きる

proc submit() =
  let d = newDialog("確かめ", name.text & " さんで送りますか。", ["送る", "やめる"])
  d.onClose = proc(choice: int) =
    summary.set(if choice == 0: "送りました: " & name.text else: "やめました")
  d.show(app)

let send = newButton("送る", submit)
let bar = newMenuBar(app, [
  ("ファイル", newMenu([menuItem("送る", submit), separator(), menuItem("終わる", (proc() = app.quit()), "Ctrl+Q")])),
  ("表示", newMenu([menuItem("消す", proc() = name.setText(""))]))])
name.onSubmit = proc(text: string) = submit()

let form = vbox(
  hbox(newLabel("名前 ").widget, name.widget.sized(fill())).sized(fixed(1)),
  notify.widget.sized(fixed(1)),
  hbox(send.widget, newWidget()).sized(fixed(1)),
  status.widget).padded(edges(1, 2)).gapped(1)
app.root = vbox(bar.widget, form)
doAssert app.focus(name.widget)    # 最初は名前の欄から (前順では帯が先)
discard app.shortcuts.add("ctrl+q", "終わる", proc() = app.quit())   # Why discard: 空の表に足すので重ならない
let ended = app.run()
if ended.isFailure: quit("form: " & ended.error, 2)
