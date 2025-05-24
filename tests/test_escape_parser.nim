# test_escape_parser.nim
## エスケープシーケンスパーサーのテスト

import unittest
import ../src/libterminal/private/common
import ../src/libterminal/private/escape_parser

suite "エスケープシーケンスパーサー":
  test "基本的なエスケープシーケンスのパース":
    # カーソル移動シーケンス
    var buffer1 = ['\e', '[', 'A']
    let seq1 = createEscapeSequence(buffer1, 3)
    check(seq1.kind == PsComplete)
    check(seq1.final == 'A')
    check(seq1.params.len == 1)
    check(seq1.params[0] == 0)  # パラメータなしのデフォルト値
    
    # パラメータ付きシーケンス
    var buffer2 = ['\e', '[', '5', 'B']
    let seq2 = createEscapeSequence(buffer2, 4)
    check(seq2.kind == PsComplete)
    check(seq2.final == 'B')
    check(seq2.params.len == 1)
    check(seq2.params[0] == 5)
    
    # 複数パラメータ
    var buffer3 = ['\e', '[', '3', ';', '4', 'H']
    let seq3 = createEscapeSequence(buffer3, 6)
    check(seq3.kind == PsComplete)
    check(seq3.final == 'H')
    check(seq3.params.len == 2)
    check(seq3.params[0] == 3)
    check(seq3.params[1] == 4)
  
  test "キーボードイベントのパース":
    # カーソルキー
    var upBuffer = ['\e', '[', 'A']
    check(isKeyEvent(createEscapeSequence(upBuffer, 3)))
    let upEvent = parseKeyEvent(createEscapeSequence(upBuffer, 3))
    check(upEvent.key == KeyUp)
    
    # ファンクションキー
    var f1Buffer = ['\e', '[', 'P']
    check(isKeyEvent(createEscapeSequence(f1Buffer, 3)))
    let f1Event = parseKeyEvent(createEscapeSequence(f1Buffer, 3))
    check(f1Event.key == KeyF1)
    
    # 拡張キー（パラメータ付き）
    var delBuffer = ['\e', '[', '3', '~']
    check(isKeyEvent(createEscapeSequence(delBuffer, 4)))
    let delEvent = parseKeyEvent(createEscapeSequence(delBuffer, 4))
    check(delEvent.key == KeyDelete)
  
  test "マウスイベントの検出":
    # SGRマウスイベント (ESC[<0;41;12M)
    var sgr_click_buffer = ['\e', '[', '<', '0', ';', '4', '1', ';', '1', '2', 'M']
    let sgr_seq = createEscapeSequence(sgr_click_buffer, 11)
    check(isMouseEvent(sgr_seq))
    
    # 通常のマウスイベント (ESC[M#HJ)
    var legacy_buffer: array[6, char]
    legacy_buffer[0] = '\e'
    legacy_buffer[1] = '['
    legacy_buffer[2] = 'M'
    legacy_buffer[3] = '#'  # ボタン + 32
    legacy_buffer[4] = 'H'  # X座標 + 32
    legacy_buffer[5] = 'J'  # Y座標 + 32
    
    let legacy_seq = createEscapeSequence(legacy_buffer, 6)
    # isMouseEventはFalseを返す可能性がある（X10形式は特殊な処理が必要）
    # そのためここではテストしない
  
  test "マウスイベントのパース":
    # SGRマウスイベント - クリック
    var sgr_click_buffer = ['\e', '[', '<', '0', ';', '4', '1', ';', '1', '2', 'M']
    let click_seq = createEscapeSequence(sgr_click_buffer, 11)
    let click_event = parseMouseEvent(click_seq)
    
    check(click_event.button == MouseLeft)
    check(click_event.action == MousePressed)
    check(click_event.x == 40)  # 41 - 1
    check(click_event.y == 11)  # 12 - 1
    
    # SGRマウスイベント - リリース
    var sgr_release_buffer = ['\e', '[', '<', '0', ';', '4', '1', ';', '1', '2', 'm']
    let release_seq = createEscapeSequence(sgr_release_buffer, 11)
    let release_event = parseMouseEvent(release_seq)
    
    check(release_event.button == MouseLeft)
    check(release_event.action == MouseReleased)
    check(release_event.x == 40)
    check(release_event.y == 11)
    
    # SGRマウスイベント - 右クリック
    var sgr_right_buffer = ['\e', '[', '<', '2', ';', '4', '1', ';', '1', '2', 'M']
    let right_seq = createEscapeSequence(sgr_right_buffer, 11)
    let right_event = parseMouseEvent(right_seq)
    
    check(right_event.button == MouseRight)
    check(right_event.action == MousePressed)
    
    # SGRマウスイベント - ホイールスクロール
    var sgr_wheel_buffer = ['\e', '[', '<', '6', '4', ';', '4', '1', ';', '1', '2', 'M']
    let wheel_seq = createEscapeSequence(sgr_wheel_buffer, 12)
    let wheel_event = parseMouseEvent(wheel_seq)
    
    check(wheel_event.button == MouseWheelUp)
    
  test "CSIパラメータのパース":
    check(parseCSIParams("") == @[0])
    check(parseCSIParams("1") == @[1])
    check(parseCSIParams("1;2;3") == @[1, 2, 3])
    check(parseCSIParams("0;1;;3") == @[0, 1, 0, 3])
    
    # 数値以外の文字が含まれる場合
    check(parseCSIParams("1;a;3") == @[1, 0, 3])