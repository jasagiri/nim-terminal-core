# Nim Terminal Library

高性能な端末操作のためのNimライブラリです。Unicode対応、マウス入力、高度な色サポート、そして効率的な描画アルゴリズムを備えています。

![RGB Color Support](https://img.shields.io/badge/RGB%20Colors-Supported-brightgreen)
![256 Colors](https://img.shields.io/badge/256%20Colors-Supported-brightgreen)
![Differential Updates](https://img.shields.io/badge/Differential%20Updates-Optimized-brightgreen)
![Unicode](https://img.shields.io/badge/Unicode-Supported-brightgreen)

## 特徴

- **Pure Nim実装**: 外部依存なしで動作
- **マルチプラットフォーム**: Linux, macOS, Windowsをサポート
- **Rawモード**: 高度なターミナル操作に対応
- **Unicode対応**: 全角文字や絵文字の正確な表示
- **マウス入力**: クリック、ドラッグ、スクロールイベントの処理
- **高度な色サポート**: 基本色、256色、RGB/TrueColorモードに対応(1670万色)、端末能力に応じた自動フォールバック
- **効率的な描画**: 差分更新による高速な画面描画
- **シグナル処理**: 適切なシグナルハンドリング

## インストール

Nimbleを使用してインストールできます：

```
nimble install libterminal
```

または、ソースからビルド：

```
git clone https://github.com/username/nim-libterminal.git
cd nim-libterminal
nimble install
```

## 基本的な使用方法

```nim
import libterminal

# 初期化
libterminal.init()

# 画面を操作
clearScreen()
hideCursor()

# 文字を表示
stdout.setCursorPos(10, 5)
stdout.write("Hello, Terminal!")

# スタイル設定
let style = Style(fg: ColorRed, bg: ColorBlack, attrs: {AttrBold})
setStyle(style)
stdout.write("Styled text!")

# 終了処理
showCursor()
libterminal.shutdown()
```

## バッファ操作と差分描画

効率的な画面更新のためのバッファ操作と差分描画：

```nim
import libterminal
import libterminal/output

# バッファを作成
let (width, height) = terminalSize()
var buffer = newBuffer(width, height)

# コンテンツを描画
buffer.print(5, 5, "Hello, Buffer!", 
  Style(fg: ColorGreen, bg: ColorDefault, attrs: {AttrBold}))

# 画面に表示（最初の描画）
buffer.drawBuffer()

# 内容を更新
buffer.print(5, 6, "Updated content!", 
  Style(fg: ColorBlue, bg: ColorDefault, attrs: {}))

# 再描画（差分のみが更新される）
buffer.drawBuffer()
```

## サンプル

- [Hello World](examples/hello_world.nim) - 基本的な使用方法
- [色のデモ](examples/color_example.nim) - 色とスタイルの使用方法
- [マウス入力](examples/mouse_example.nim) - マウス入力の処理
- [シグナル処理](examples/signal_handling.nim) - シグナルハンドリング
- [Unicode対応](examples/unicode_example.nim) - 全角文字の表示
- [差分更新デモ](examples/diff_update_example.nim) - 効率的な差分描画の実演

## ドキュメント

- [ターミナル初期化](docs/terminal_initialization.md)
- [マウス入力](docs/mouse_input.md)
- [シグナル処理](docs/signal_handling.md)
- [高度な色](docs/advanced_colors.md)
- [Unicode対応](docs/unicode_support.md)
- [効率的な描画](docs/differential_updates.md)

## ライセンス

MIT

## 貢献

バグ報告、機能リクエスト、プルリクエストは大歓迎です。