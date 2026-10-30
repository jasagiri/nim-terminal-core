## 進み具合: タイマーで 100 まで進め、ETA を見せる。終わったら q で終わる。

import nim_terminal_core

let bar = newProgressBar(100, nowMs(), "取込")
bar.showRate = true
let hint = newLabel("q で終わる", role = roMuted)
let app = newApp(vbox(bar.widget, hint.widget).padded(edges(1, 2)))
var done = 0
var ticking: Timer
ticking = app.every(80, proc() =
  inc done
  bar.update(done, nowMs())
  if done >= 100: ticking.cancel())
discard app.shortcuts.add("q", "終わる", proc() = app.quit())   # Why discard: 空の表に足すので重ならない
let ended = app.run()
if ended.isFailure: quit("progress: " & ended.error, 2)
