Feature: 拡張色サポート
  最新のターミナルでは、基本の16色だけでなく
  256色やRGB色もサポートされています

  Scenario: 256色モードの検出
    Given ターミナルが初期化されている
    When 端末の色サポートを検出する
    Then 対応する色モードが返される
    And 256色対応ならTrue、それ以外はFalseが返される

  Scenario: RGB色モードの検出
    Given ターミナルが初期化されている
    When 端末のRGB色サポートを検出する
    Then 対応する色モードが返される
    And TrueColor対応ならTrue、それ以外はFalseが返される

  Scenario: 256色の設定
    Given ターミナルが256色モードで初期化されている
    When 背景色を256色の一つに設定する
    Then 適切なエスケープシーケンスが生成される
    And その色が画面上で表示される

  Scenario: RGB色の設定
    Given ターミナルがRGB色モードで初期化されている
    When 背景色をRGB値で設定する
    Then 適切なエスケープシーケンスが生成される
    And その色が画面上で表示される

  Scenario: 基本色へのフォールバック
    Given ターミナルが基本色モードのみをサポートしている
    When 256色またはRGB色を設定しようとする
    Then 近似した基本色に自動的に変換される