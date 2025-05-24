# unicode_example.nim
## Unicode対応のデモンストレーション
## 
## このサンプルでは、様々なUnicode文字の表示と処理を行います。
## 全角文字、結合文字、絵文字などの処理を示します。

import libterminal
import std/unicode

proc main() =
  # 初期化
  withTerminal:
    # 初期サイズを取得
    let (width, height) = raw.getTerminalSize()
    
    # バッファを作成
    var buffer = newBuffer(width, height)
    
    # 画面をクリア
    clearScreen()
    
    # タイトル
    let titleStyle = Style(
      fg: ColorCyan,
      bg: ColorDefault,
      attrs: {AttrBold}
    )
    buffer.print(2, 1, "Unicode文字表示デモンストレーション", titleStyle)
    
    # 基本的なASCII文字
    buffer.print(2, 3, "ASCII: The quick brown fox jumps over the lazy dog.")
    
    # 全角文字（日本語）
    buffer.print(2, 5, "全角日本語: こんにちは世界、これは日本語のテストです。")
    
    # 全角文字（中国語）
    buffer.print(2, 7, "全角中国語: 你好世界，这是中文测试。")
    
    # 全角文字（韓国語）
    buffer.print(2, 9, "全角韓国語: 안녕하세요 세계, 이것은 한국어 테스트입니다.")
    
    # 結合文字
    buffer.print(2, 11, "結合文字: e\u0301 a\u0300 i\u0302 o\u0308 u\u0303")
    
    # アラビア語（右から左）
    buffer.print(2, 13, "アラビア語: مرحبا بالعالم، هذا اختبار للغة العربية.")
    
    # ヘブライ語（右から左）
    buffer.print(2, 15, "ヘブライ語: שלום עולם, זהו מבחן בעברית.")
    
    # 絵文字
    buffer.print(2, 17, "絵文字: 😀 🚀 🌍 🎮 🍕 📱 🐱 🌈")
    
    # 混合テキスト
    buffer.print(2, 19, "混合テキスト: Hello 你好 안녕하세요 こんにちは 😊")
    
    # 文字幅情報
    buffer.print(2, 21, "文字幅情報:")
    
    let chars = [
      "A", "あ", "世", "안", "😀", "é", "م"
    ]
    
    let widthStyle = Style(
      fg: ColorYellow,
      bg: ColorDefault,
      attrs: {}
    )
    
    # 各文字の幅情報を表示
    for i, c in chars:
      let r = c.toRunes[0]
      let w = runeWidth(r)
      buffer.print(4, 22 + i, c & ": 幅 = " & $w, widthStyle)
    
    # 効率的な描画でバッファを表示
    drawBuffer(buffer)
    
    # 何かキーが押されるまで待機
    discard input.pollEvent()

when isMainModule:
  main()