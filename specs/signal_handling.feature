Feature: シグナルハンドリング
  ターミナルアプリケーションは様々なシグナルを
  適切に処理する必要があります

  Scenario: SIGINT (Ctrl+C) の処理
    Given ターミナルがRawモードで初期化されている
    When Ctrl+Cが押される
    Then SIGINTシグナルがイベントとして捕捉される
    And アプリケーションは例外を発生させずに制御を維持する

  Scenario: SIGWINCH (ウィンドウサイズ変更) の処理
    Given ターミナルがRawモードで初期化されている
    When ターミナルのサイズが変更される
    Then SIGWINCHシグナルがイベントとして捕捉される
    And リサイズイベントがイベントキューに追加される
    And 新しいターミナルサイズが取得できる

  Scenario: SIGTERM の処理
    Given ターミナルがRawモードで初期化されている
    When SIGTERMシグナルが送信される
    Then ターミナルは適切にクリーンアップされる
    And アプリケーションは正常に終了する

  Scenario: シグナルハンドラの復元
    Given ターミナルがRawモードで初期化されている
    And シグナルハンドラがカスタマイズされている
    When ターミナルの終了処理が実行される
    Then 元のシグナルハンドラが復元される