## いちばん小さいアプリ: 文字とボタン。Enter かクリックで終わる。

import nim_terminal_core

let greeting = newLabel("こんにちは、端末。", align = alCenter)
let app = newApp(newWidget())
let done = newButton("終わる", proc() = app.quit())
app.root = vbox(greeting.widget, hbox(newWidget(), done.widget, newWidget())).padded(edges(1))
let ended = app.run()
if ended.isFailure: quit("hello: " & ended.error, 2)
