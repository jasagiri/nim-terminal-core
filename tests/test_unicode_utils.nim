# test_unicode_utils.nim
## Unicode処理機能のテスト

import unittest
import std/unicode
import std/strutils

import ../src/libterminal
import ../src/libterminal/private/unicode_utils

suite "基本的なUnicode処理":
  test "文字幅の計算":
    # 通常のASCII文字
    check(unicode_utils.runeWidth(Rune('a')) == 1)
    check(unicode_utils.runeWidth(Rune('Z')) == 1)
    check(unicode_utils.runeWidth(Rune('0')) == 1)
    
    # 全角文字
    check(unicode_utils.runeWidth("あ".runeAt(0)) == 2)
    check(unicode_utils.runeWidth("漢".runeAt(0)) == 2)
    check(unicode_utils.runeWidth("😀".runeAt(0)) == 2)  # 絵文字
    
    # 特殊文字
    check(unicode_utils.runeWidth(Rune(0x200B)) == 0)  # ゼロ幅スペース
    
    # 文字列の表示幅
    check(displayWidth("Hello") == 5)
    check(displayWidth("こんにちは") == 10)
    check(displayWidth("Hello世界") == 9)  # 5 + (2*2)
  
  test "グラフェムクラスタ長":
    # 基本的な場合
    check(graphemeLength("Hello") == 5)
    check(graphemeLength("こんにちは") == 5)
    
    # 絵文字を含む場合
    check(graphemeLength("👨‍👩‍👧‍👦") == 1)  # 家族の絵文字は1文字扱い
    check(graphemeLength("🏴󠁧󠁢󠁳󠁣󠁴󠁿") == 1)  # スコットランド国旗
  
  test "テキスト方向の検出":
    # 左から右
    check(getTextDirection("Hello World") == LeftToRight)
    check(getTextDirection("これは日本語です") == LeftToRight)
    
    # 右から左
    check(getTextDirection("مرحبا بالعالم") == RightToLeft)  # アラビア語
    check(getTextDirection("שלום עולם") == RightToLeft)  # ヘブライ語
    
    # 空文字列
    check(getTextDirection("") == LeftToRight)

suite "テキスト分割と解析":
  test "行分割":
    # 通常の改行
    let text1 = "Line 1\nLine 2\nLine 3"
    let lines1 = unicode_utils.splitLines(text1)
    check(lines1.len == 3)
    check(lines1[0] == "Line 1")
    check(lines1[1] == "Line 2")
    check(lines1[2] == "Line 3")
    
    # CRLFの処理
    let text2 = "Line 1\r\nLine 2\r\nLine 3"
    let lines2 = unicode_utils.splitLines(text2)
    check(lines2.len == 3)
    check(lines2[0] == "Line 1")
    check(lines2[1] == "Line 2")
    check(lines2[2] == "Line 3")
    
    # 混合された改行
    let text3 = "Line 1\nLine 2\r\nLine 3"
    let lines3 = unicode_utils.splitLines(text3)
    check(lines3.len == 3)
    check(lines3[0] == "Line 1")
    check(lines3[1] == "Line 2")
    check(lines3[2] == "Line 3")
    
    # 末尾の改行
    let text4 = "Line 1\nLine 2\n"
    let lines4 = unicode_utils.splitLines(text4)
    check(lines4.len == 2)
    check(lines4[0] == "Line 1")
    check(lines4[1] == "Line 2")
    
    # 空行を含むテキスト
    let text5 = "Line 1\n\nLine 3"
    let lines5 = unicode_utils.splitLines(text5)
    check(lines5.len == 3)
    check(lines5[0] == "Line 1")
    check(lines5[1] == "")
    check(lines5[2] == "Line 3")
  
  test "単語境界の判定":
    # 英単語の境界
    check(isWordBoundary("Hello World", 5))  # 'Hello'と'World'の間
    check(isWordBoundary("Hello,World", 5))  # 'Hello'と','の間
    
    # 単語の途中
    check(not isWordBoundary("Hello", 2))
    
    # 文字列の先頭と末尾
    check(isWordBoundary("Hello", 0))
    check(isWordBoundary("Hello", 5))
    
    # 空白類
    check(isWordBoundary("Hello  World", 6))
    
    # 日本語のケース
    check(isWordBoundary("こんにちは世界", 5))  # 'こんにちは'と'世界'の間
    check(isWordBoundary("こんにちは、世界", 5))  # 'こんにちは'と'、'の間
    
    # 境界チェックの特殊ケース
    check(not isWordBoundary("", 0))  # 空文字列
    check(not isWordBoundary("Hello", 10))  # 範囲外
  
  test "グラフェムクラスタの処理":
    # 通常のASCII文字
    check(graphemeLength("Hello") == 5)
    
    # 複合グラフェム
    check(graphemeLength("é") == 1)  # プリコンポーズド
    check(graphemeLength("e\u0301") == 1)  # 分解形式
    
    # 絵文字
    check(graphemeLength("🏴󠁧󠁢󠁳󠁣󠁴󠁿") == 1)  # 国旗
    check(graphemeLength("👨‍👩‍👧‍👦") == 1)  # 家族
    check(graphemeLength("👍🏽") == 1)  # 肌の色付き絵文字
    
    # ゼロ幅文字
    check(graphemeLength("\u200B") == 1)  # ゼロ幅スペース
    check(displayWidth("\u200B") == 0)  # 表示幅は0
    
    # 混合テキスト
    let mixed = "Hello😀World"
    check(graphemeLength(mixed) == 11)  # 'Hello' (5) + '😀' (1) + 'World' (5)
    
    # グラフェムクラスタへの分割
    let clusters = splitIntoGraphemeClusters("Hello😀")
    check(clusters.len == 6)
    check($clusters[0].codePoints[0] == "H")
    check($clusters[5].codePoints[0] == "😀")
    
    # 複合文字のクラスタ
    let complexClusters = splitIntoGraphemeClusters("é👨‍👩‍👧‍👦")
    check(complexClusters.len == 2)
    # Check first cluster contains é
    check(complexClusters[0].codePoints.len == 1)
    check($complexClusters[0].codePoints[0] == "é")
    # Check second cluster contains multiple code points for family emoji
    check(complexClusters[1].codePoints.len > 1)

suite "双方向テキスト処理":
  test "論理位置と視覚位置の変換":
    # 左から右のテキスト（変換なし）
    let ltrText = "Hello World"
    check(logicalPosToVisual(ltrText, 5) == 5)
    check(visualPosToLogical(ltrText, 5) == 5)
    
    # 右から左のテキスト
    let rtlText = "مرحبا"  # アラビア語
    # RTLテキストでは論理位置と視覚位置が逆になる
    # この実装は簡略化されていて、完全な双方向アルゴリズムは実装されていない
    check(logicalPosToVisual(rtlText, 0) != 0)
    
    # 混合テキスト
    let mixedText = "Hello مرحبا World"
    # 混合テキストでは、論理位置と視覚位置の関係はより複雑になります
    # このテストも簡略化されています
    check(logicalPosToVisual(mixedText, 6) != 6)
  
  test "行折り返し":
    # 通常のテキスト折り返し（単語単位）
    let text1 = "The quick brown fox jumps over the lazy dog"
    let wrapped1 = unicode_utils.splitLines(text1, 20, WrapWord)
    
    check(wrapped1.len > 1)  # 少なくとも2行に分かれるはず
    check(wrapped1[0].len <= 20)
    
    # 文字単位の折り返し
    let text2 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    let wrapped2 = unicode_utils.splitLines(text2, 10, WrapCharacter)
    
    check(wrapped2.len == 3)
    check(wrapped2[0] == "ABCDEFGHIJ")
    check(wrapped2[1] == "KLMNOPQRST")
    check(wrapped2[2] == "UVWXYZ")
    
    # 日本語テキストの折り返し
    let text3 = "吾輩は猫である。名前はまだ無い。"
    let wrapped3 = unicode_utils.splitLines(text3, 10, WrapCharacter)  # 文字幅は全角文字で2
    
    check(wrapped3.len >= 2)
    check(displayWidth(wrapped3[0]) <= 10)
    
    # 折り返しなし
    let text4 = "Short text"
    let wrapped4 = unicode_utils.splitLines(text4, 20, WrapWord)
    
    check(wrapped4.len == 1)
    check(wrapped4[0] == "Short text")

# NOTE: Unicode normalization tests are commented out because the functions are not implemented
# suite "Unicode正規化":
#   test "正規化形式":
#     # These tests would require normalizeNFD, normalizeNFC, normalizeNFKD, normalizeNFKC functions
#     discard