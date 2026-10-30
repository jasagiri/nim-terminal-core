# test_unicode_utils.nim
## Unicode processing functionality tests

import unittest
import std/unicode
import std/strutils

import ../src/libterminal
import ../src/libterminal/private/unicode_utils

suite "Basic Unicode processing":
  test "Character width calculation":
    # Normal ASCII characters
    check(unicode_utils.runeWidth(Rune('a')) == 1)
    check(unicode_utils.runeWidth(Rune('Z')) == 1)
    check(unicode_utils.runeWidth(Rune('0')) == 1)
    
    # Full-width characters
    check(unicode_utils.runeWidth("あ".runeAt(0)) == 2)
    check(unicode_utils.runeWidth("漢".runeAt(0)) == 2)
    check(unicode_utils.runeWidth("😀".runeAt(0)) == 2)  # Emoji
    
    # Special characters
    check(unicode_utils.runeWidth(Rune(0x200B)) == 0)  # Zero-width space
    
    # String display width
    check(displayWidth("Hello") == 5)
    check(displayWidth("こんにちは") == 10)  # "Hello" in Japanese
    check(displayWidth("Hello世界") == 9)  # 5 + (2*2)
  
  test "Grapheme cluster length":
    # Basic cases
    check(graphemeLength("Hello") == 5)
    check(graphemeLength("こんにちは") == 5)  # 5 Japanese characters
    
    # Cases with emoji
    check(graphemeLength("👨‍👩‍👧‍👦") == 1)  # Family emoji counts as 1 character
    check(graphemeLength("🏴󠁧󠁢󠁳󠁣󠁴󠁿") == 1)  # Scotland flag
  
  test "Text direction detection":
    # Left to right
    check(getTextDirection("Hello World") == LeftToRight)
    check(getTextDirection("これは日本語です") == LeftToRight)  # "This is Japanese"
    
    # Right to left
    check(getTextDirection("مرحبا بالعالم") == RightToLeft)  # Arabic
    check(getTextDirection("שלום עולם") == RightToLeft)  # Hebrew
    
    # Empty string
    check(getTextDirection("") == LeftToRight)

suite "Text splitting and parsing":
  test "Line splitting":
    # Normal line breaks
    let text1 = "Line 1\nLine 2\nLine 3"
    let lines1 = unicode_utils.splitLines(text1)
    check(lines1.len == 3)
    check(lines1[0] == "Line 1")
    check(lines1[1] == "Line 2")
    check(lines1[2] == "Line 3")
    
    # CRLF handling
    let text2 = "Line 1\r\nLine 2\r\nLine 3"
    let lines2 = unicode_utils.splitLines(text2)
    check(lines2.len == 3)
    check(lines2[0] == "Line 1")
    check(lines2[1] == "Line 2")
    check(lines2[2] == "Line 3")
    
    # Mixed line breaks
    let text3 = "Line 1\nLine 2\r\nLine 3"
    let lines3 = unicode_utils.splitLines(text3)
    check(lines3.len == 3)
    check(lines3[0] == "Line 1")
    check(lines3[1] == "Line 2")
    check(lines3[2] == "Line 3")
    
    # Trailing line break
    let text4 = "Line 1\nLine 2\n"
    let lines4 = unicode_utils.splitLines(text4)
    check(lines4.len == 2)
    check(lines4[0] == "Line 1")
    check(lines4[1] == "Line 2")
    
    # Text with empty lines
    let text5 = "Line 1\n\nLine 3"
    let lines5 = unicode_utils.splitLines(text5)
    check(lines5.len == 3)
    check(lines5[0] == "Line 1")
    check(lines5[1] == "")
    check(lines5[2] == "Line 3")
  
  test "Word boundary detection":
    # English word boundaries
    check(isWordBoundary("Hello World", 5))  # Between 'Hello' and 'World'
    check(isWordBoundary("Hello,World", 5))  # Between 'Hello' and ','
    
    # Middle of word
    check(not isWordBoundary("Hello", 2))
    
    # Start and end of string
    check(isWordBoundary("Hello", 0))
    check(isWordBoundary("Hello", 5))
    
    # Whitespace
    check(isWordBoundary("Hello  World", 6))
    
    # Japanese cases
    check(isWordBoundary("こんにちは世界", 5))  # Between 'こんにちは' and '世界'
    check(isWordBoundary("こんにちは、世界", 5))  # Between 'こんにちは' and '、'
    
    # Special cases for boundary checking
    check(not isWordBoundary("", 0))  # Empty string
    check(not isWordBoundary("Hello", 10))  # Out of range
  
  test "Grapheme cluster processing":
    # Normal ASCII characters
    check(graphemeLength("Hello") == 5)
    
    # Compound graphemes
    check(graphemeLength("é") == 1)  # Precomposed
    check(graphemeLength("e\u0301") == 1)  # Decomposed form
    
    # Emoji
    check(graphemeLength("🏴󠁧󠁢󠁳󠁣󠁴󠁿") == 1)  # Flag
    check(graphemeLength("👨‍👩‍👧‍👦") == 1)  # Family
    check(graphemeLength("👍🏽") == 1)  # Emoji with skin tone
    
    # Zero-width characters
    check(graphemeLength("\u200B") == 1)  # Zero-width space
    check(displayWidth("\u200B") == 0)  # Display width is 0
    
    # Mixed text
    let mixed = "Hello😀World"
    check(graphemeLength(mixed) == 11)  # 'Hello' (5) + '😀' (1) + 'World' (5)
    
    # Splitting into grapheme clusters
    let clusters = splitIntoGraphemeClusters("Hello😀")
    check(clusters.len == 6)
    check($clusters[0].codePoints[0] == "H")
    check($clusters[5].codePoints[0] == "😀")
    
    # Compound character clusters
    let complexClusters = splitIntoGraphemeClusters("é👨‍👩‍👧‍👦")
    check(complexClusters.len == 2)
    # Check first cluster contains é
    check(complexClusters[0].codePoints.len == 1)
    check($complexClusters[0].codePoints[0] == "é")
    # Check second cluster contains multiple code points for family emoji
    check(complexClusters[1].codePoints.len > 1)

suite "Bidirectional text processing":
  test "Logical to visual position conversion":
    # Left-to-right text (no conversion)
    let ltrText = "Hello World"
    check(logicalPosToVisual(ltrText, 5) == 5)
    check(visualPosToLogical(ltrText, 5) == 5)
    
    # Right-to-left text
    let rtlText = "مرحبا"  # Arabic
    # In RTL text, logical and visual positions are reversed
    # This implementation is simplified and does not implement the full bidirectional algorithm
    check(logicalPosToVisual(rtlText, 0) != 0)
    
    # Mixed text
    let mixedText = "Hello مرحبا World"
    # In mixed text, the relationship between logical and visual positions becomes more complex
    # This test is also simplified
    check(logicalPosToVisual(mixedText, 6) != 6)
  
  test "Line wrapping":
    # Normal text wrapping (word-based)
    let text1 = "The quick brown fox jumps over the lazy dog"
    let wrapped1 = unicode_utils.splitLines(text1, 20, WrapWord)
    
    check(wrapped1.len > 1)  # Should be split into at least 2 lines
    check(wrapped1[0].len <= 20)
    
    # Character-based wrapping
    let text2 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    let wrapped2 = unicode_utils.splitLines(text2, 10, WrapCharacter)
    
    check(wrapped2.len == 3)
    check(wrapped2[0] == "ABCDEFGHIJ")
    check(wrapped2[1] == "KLMNOPQRST")
    check(wrapped2[2] == "UVWXYZ")
    
    # Japanese text wrapping
    let text3 = "吾輩は猫である。名前はまだ無い。"
    let wrapped3 = unicode_utils.splitLines(text3, 10, WrapCharacter)  # Character width is 2 for full-width characters
    
    check(wrapped3.len >= 2)
    check(displayWidth(wrapped3[0]) <= 10)
    
    # No wrapping
    let text4 = "Short text"
    let wrapped4 = unicode_utils.splitLines(text4, 20, WrapWord)
    
    check(wrapped4.len == 1)
    check(wrapped4[0] == "Short text")

# NOTE: Unicode normalization tests are commented out because the functions are not implemented
# suite "Unicode正規化":
#   test "正規化形式":
#     # These tests would require normalizeNFD, normalizeNFC, normalizeNFKD, normalizeNFKC functions
#     discard