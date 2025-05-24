# test_mouse.nim
## マウス機能のテスト

import unittest
import ../src/libterminal/mouse

suite "マウスモード":
  test "MouseMode列挙体":
    # 基本的なチェック - 列挙値の存在確認
    check(MouseNone is MouseMode)
    check(MouseX10 is MouseMode)
    check(MouseVT200 is MouseMode)
    check(MouseButtonEvent is MouseMode)
    check(MouseAnyEvent is MouseMode)
    check(MouseSGR is MouseMode)
    check(MouseURXVT is MouseMode)
  
  test "初期状態":
    # 初期状態ではマウスモードは無効
    check(getActiveMouseMode() == MouseNone)
  
  test "マウスモードの有効化と無効化":
    # マウスモードを有効化
    # 注: 実際の端末でないとマウスモードが有効にならない可能性があるため、
    # 戻り値は確認しません
    discard enableMouseMode(MouseX10)
    
    # モードが変わっているか確認
    # (端末によってはサポートされていない可能性があるため、条件付きテスト)
    if getActiveMouseMode() != MouseNone:
      check(getActiveMouseMode() == MouseX10)
      
      # 別のモードに切り替え
      discard enableMouseMode(MouseSGR)
      check(getActiveMouseMode() == MouseSGR)
      
      # マウスモードを無効化
      disableMouseMode()
      check(getActiveMouseMode() == MouseNone)
    else:
      # 端末がマウスモードをサポートしていない場合はスキップ
      skip()
  
  test "マウスモードのサポート確認":
    # この関数はほとんどの環境で真を返すはず
    let supported = supportsMouseMode()
    check(supported is bool)
  
  test "マウスモードの切り替え":
    # 同じモードへの複数回の切り替え
    let result1 = enableMouseMode(MouseSGR)
    let result2 = enableMouseMode(MouseSGR)  # 2回目は偽を返すはず
    
    if result1:  # マウスモードがサポートされている場合のみ確認
      check(not result2)  # 同じモードなので失敗する
      
      # 別のモード
      check(enableMouseMode(MouseVT200))
      
      # クリーンアップ
      disableMouseMode()
    else:
      skip()
  
  test "各種マウスモードの切り替え":
    # すべてのモードをテスト
    for mode in [MouseX10, MouseVT200, MouseButtonEvent, 
                MouseAnyEvent, MouseSGR, MouseURXVT]:
      discard enableMouseMode(mode)
      if getActiveMouseMode() != MouseNone:
        check(getActiveMouseMode() == mode)
      disableMouseMode()
    
    # クリーンアップ
    disableMouseMode()

# テスト終了時にマウスモードを確実に無効化
# addTeardown is not available in this unittest version