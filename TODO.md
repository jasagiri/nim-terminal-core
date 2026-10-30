# nim-libterminal TODO


## 重要
[] プロジェクト名をnim-terminal-coreに変更し、import terminal_core で利用できるように



## ✅ 修正済み (2025-05-27)

### 1. コンパイルエラー修正
- **修正内容**: `handleEvent`メソッドの型不整合を修正
  - `WidgetEvent` → `Event`に統一
  - `EvKey`イベントタイプを使用
  - プリント可能文字の処理を修正
- **結果**: agent_widgets.nimがコンパイル可能に

## 🔴 Critical Issues (残存する問題)

### 1. コンパイルエラー
- **問題**: `libterminal/agents/agent_widgets.nim(157, 30)` でタイプミスマッチエラー
  ```
  Error: type mismatch
  Expression: handleEvent(widget.parent, messageEvent)
  [1] widget.parent: Widget
  [2] messageEvent: WidgetEvent
  ```
- **原因**: WidgetEventとEventの型が混在している
- **影響**: RealeOSでlibterminalの完全な機能が使用できない
- **対応**: 一時的にwidget関連のインポートを無効化

### 2. API不整合
- **問題**: ドキュメントと実際のAPIが一致しない箇所がある
- **例**: 
  - `Terminal`型が見つからない
  - `terminalSize()`の戻り値の型が異なる
- **対応**: 基本機能のみ使用し、高度な機能は保留

## 🟡 Integration Issues (統合上の課題)

### 1. 依存関係
- **問題**: パッケージ構造が複雑で、部分的なインポートが困難
- **改善案**: 
  - コアモジュールと拡張モジュールの分離
  - 最小限の依存関係で動作するcore版の提供

### 2. Raw Mode管理
- **問題**: Raw modeの状態管理が呼び出し側に委ねられている
- **改善案**: 
  - 自動的な状態管理機能の追加
  - RAII パターンの実装

## 🟢 Feature Enhancements (機能強化)

### 1. エラーハンドリング
- より詳細なエラーメッセージ
- エラーリカバリー機能

### 2. クロスプラットフォーム対応
- Windows Terminal対応の強化
- WASI環境での動作確認

### 3. パフォーマンス
- 差分更新アルゴリズムの最適化
- メモリ使用量の削減

## 📋 Refactoring Tasks

### 1. モジュール構造の見直し
```nim
# 現在
libterminal/
├── agents/       # 依存関係が複雑
├── input.nim
├── output.nim
└── widgets.nim

# 提案
libterminal/
├── core/         # 最小限の機能
│   ├── terminal.nim
│   ├── input.nim
│   └── output.nim
├── widgets/      # オプショナル
│   ├── base.nim
│   └── ...
└── libterminal.nim  # 統合エクスポート
```

### 2. 型システムの整理
- Event型とWidgetEvent型の統合
- より明確な型階層の定義

## 🚀 Future Plans

### 1. RealeOS統合の完全サポート
- [ ] widget系のコンパイルエラー修正
- [ ] fuzzy_finderでの完全なwidget活用
- [ ] terminal_inputでの高度な入力機能

### 2. ドキュメント改善
- [ ] APIリファレンスの更新
- [ ] 統合ガイドの作成
- [ ] サンプルコードの充実

### 3. テスト強化
- [ ] 統合テストの追加
- [ ] クロスプラットフォームテスト
- [ ] パフォーマンステスト

## 📅 Timeline

- **Phase 1** (即座): コンパイルエラーの修正
- **Phase 2** (1週間): API整合性の確保
- **Phase 3** (2週間): モジュール構造の改善
- **Phase 4** (1ヶ月): 完全な統合サポート
