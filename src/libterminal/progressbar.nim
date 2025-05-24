# progressbar.nim
## プログレスバーウィジェット

import widget_base
import widgets

type
  ProgressBarState* = ref object of WidgetState
    value*: float  # 0.0 〜 1.0 の範囲

  ProgressBar* = ref object of Widget

proc newProgressBar*(id: string, initialValue: float = 0.0): ProgressBar =
  ## 新しいプログレスバーを作成
  result = ProgressBar()
  result.id = id
  
  # 初期状態設定
  var state = ProgressBarState()
  state.value = max(0.0, min(1.0, initialValue))  # 0.0〜1.0に制限
  result.state = state
  
  # デフォルトフラグ設定
  result.flags = {WidgetVisible, WidgetEnabled}

proc getValue*(progressBar: ProgressBar): float =
  ## 現在の値を取得 (0.0〜1.0)
  ProgressBarState(progressBar.state).value

proc setValue*(progressBar: ProgressBar, value: float) =
  ## 値を設定 (0.0〜1.0の範囲に制限)
  let state = ProgressBarState(progressBar.state)
  state.value = max(0.0, min(1.0, value))

proc setProgress*(progressBar: ProgressBar, progress: float) =
  ## 値を設定（setValue のエイリアス）
  progressBar.setValue(progress)

proc getProgress*(progressBar: ProgressBar): float =
  ## 現在の値を取得（getValue のエイリアス）
  progressBar.getValue()