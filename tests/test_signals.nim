# test_signals.nim
## シグナル処理関連のテスト

import unittest
import std/options
import ../src/libterminal
import ../src/libterminal/private/signals

suite "シグナル処理":
  test "シグナルハンドラの登録と復元":
    # シグナルハンドラを登録
    check(registerSignalHandlers())
    
    # ハンドラを復元
    restoreSignalHandlers()
  
  test "シグナルコールバック":
    var callbackCalled = false
    var receivedSignal: SignalType
    
    # テスト用コールバック
    proc testCallback(sigType: SignalType) =
      callbackCalled = true
      receivedSignal = sigType
    
    # コールバックを登録
    addSignalCallback(testCallback)
    
    # コールバックを削除
    removeSignalCallback(testCallback)
    
    # シグナルイベントをクリア
    clearSignalEvents()
    
    # シグナルイベントが空になったことを確認
    check(getSignalEvent().isNone)

when isMainModule:
  # テストを実行
  discard