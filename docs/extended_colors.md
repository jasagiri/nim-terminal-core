# 拡張カラーサポート

libterminal ライブラリは、ターミナルのカラー表示能力に応じて自動的に最適な色表現を選択する高度なカラーサポートを提供します。

## カラーモード

以下の4つのカラーモードをサポートしています：

1. **BasicColor (8色)**: すべての端末で動作する基本的なANSI色
2. **BrightColor (16色)**: 基本色＋明るい色のバリエーション
3. **256色モード**: xterm-256color互換の256色パレット
4. **RGB/TrueColor**: 16,777,216色（24ビットカラー）

ライブラリは起動時に`detectColorSupport()`関数を使用して、現在の端末が対応している最高の色モードを自動検出します。

## 使用方法

### 基本的な色の使用

```nim
import libterminal/output

# バッファを作成
var buffer = newBuffer(width, height)

# 標準のStyle型で基本色を使用
let style = Style(fg: ColorRed, bg: ColorBlack, attrs: {})
buffer.print(x, y, "赤色のテキスト", style)
```

### RGB色の使用

```nim
import libterminal/output
import libterminal/private/color_utils

# RGB色を直接指定
let redColor = RGBColor(r: 255, g: 0, b: 0)
let blueColor = RGBColor(r: 0, g: 0, b: 255)

# RGB色を使用して描画（端末が対応していない場合は自動的に近似色にフォールバック）
buffer.printRGB(x, y, "RGB色のテキスト", redColor, blueColor)
```

### 色名による指定

```nim
import libterminal/output

# X11の色名を使用
buffer.printColorName(x, y, "名前付き色のテキスト", DeepSkyBlue, Black)
```

## 自動フォールバック

拡張色機能の重要な特徴は、端末の能力に合わせた自動フォールバックです：

- RGB色をサポートしない端末では、最も近い256色または基本色に変換されます
- 256色をサポートしない端末では、最も近い基本色に変換されます

これにより、あらゆる環境で最適な表示が可能になります。

## 差分描画との連携

拡張色情報は差分描画アルゴリズムと完全に統合されています：

- RGB色や256色で描画された内容も効率的に差分計算されます
- 色情報の変更のみの場合も最適化されます
- 端末の色サポートに応じて適切な描画コマンドが選択されます

## 色パレット

### 16色パレット

基本的なANSI色セット：
- Black, Red, Green, Yellow
- Blue, Magenta, Cyan, White
- BrightBlack, BrightRed, BrightGreen, BrightYellow
- BrightBlue, BrightMagenta, BrightCyan, BrightWhite

### 256色パレット

- インデックス 0-15: 基本16色
- インデックス 16-231: 6x6x6 RGBカラーキューブ
- インデックス 232-255: グレースケール

### RGB/TrueColor

- 各色成分(R,G,B)に対して0-255の値を指定できます（24ビットカラー）
- 1670万色以上の表現が可能です

## サンプル

拡張色のデモサンプル：
- [extended_color_example.nim](../examples/extended_color_example.nim): 拡張色のデモ
- [color_example.nim](../examples/color_example.nim): 基本色のデモ