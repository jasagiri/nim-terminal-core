# nim-terminal-core

端末の中で動く道具のための TUI の枠組み。ウィジェットの木、割り付け、フォーカスとマウスの振り分け、ショートカット、型つきのバインディング、よく使うウィジェット。端末と話すこと (raw、キーの解読、差分の描画) は nim-terminal-io が持つ。macOS と Linux で動く。

```nim
import nim_terminal_core

let app = newApp(newWidget())
let name = newTextInput(placeholder = "名前")
let greeting = newLabel()
name.onSubmit = proc(text: string) = greeting.setText("こんにちは、" & text & " さん")
app.root = vbox(
  hbox(newLabel("名前 ").widget, name.widget.sized(fill())).sized(fixed(1)),
  greeting.widget,
  newButton("終わる", proc() = app.quit()).widget).padded(edges(1, 2)).gapped(1)
discard app.shortcuts.add("ctrl+q", "終わる", proc() = app.quit())
let ended = app.run()          # 端末を raw・代替画面にし、どの終わり方でも戻す
if ended.isFailure: quit("example: " & ended.error, 2)
```

| module | 役目 |
|---|---|
| `widget` | ウィジェットの木。描画・事象・大きさ・子の置き方を `Behavior` (手続きの束) に委ねる。継承と method は使わない |
| `layout` | 縦・横・重ね・格子・任意の割り付け。大きさは `fixed`・`percent`・`natural`・`fill` |
| `canvas` | ウィジェットが描く先。原点と切り抜きを持ち、書記素クラスタと幅 2 の文字を扱う。`box` で枠 |
| `event`・`app` | キー・貼り付け・マウス (クリックとダブルクリックを作る) をフォーカスやマウスの下のウィジェットへ渡し、親へ伝える。ダイアログ・メニューの層、タイマー、fd の見張り、端末との実行ループ |
| `shortcuts` | キーの組み合わせ (`"ctrl+s"`) と動作。文脈を積む |
| `binding` | `Observable[T]`: 値が変わったら知らせる。ウィジェットと両向きにつなぐ |
| `theme` | 役割 (roFocused・roSelected など) ごとのスタイルと枠の字 |
| `lineedit` | 1 行の編集 (書記素クラスタ単位、Emacs のキー)。TextInput とシェルが使う |
| `asyncloop` | std/asyncdispatch の仕事を実行ループで回す (`driveAsync`)。既定の import には入らない |
| `widgets/*` | Label・Button・Checkbox・TextInput・ListBox・ProgressBar・ScrollView・Dialog・Menu・MenuBar・TabView・TreeView・TableView |

- 規則は ADR-TC-0001 (枠組み) と ADR-TC-0002 (行の編集とウィジェット)。前の版の `specs/*.feature` との対応は `docs/spec/previous-features.md`。
- 例は `examples/` (hello、form、files、progress)。`nim examples` で `build/` に組む。
- 依存: `../nim-terminal-io`、`../nim-unicode-width`、`../../nim-outcome` (nim.cfg で source から)。試験の擬似端末は `../nim-libplatform`。`nim test` でテスト。
- 作り直す前の中身 (端末の層、アクター、エージェント、9P、計測) は jj の履歴の「chore: keep the work in progress before the rebuild」にある。アクターは nim-tui-actors に切り出した。エージェントは nim-tui-agents、計測は nim-tui-metrics に切り出した。
- ライセンスは Apache-2.0 (`LICENSE`、`NOTICE`)。2026 年の作り直しより前の版 (nim-libterminal の名で公開) は MIT。
