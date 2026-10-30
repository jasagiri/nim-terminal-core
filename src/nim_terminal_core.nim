## TUI の枠組み。ウィジェットの木 (委譲)、割り付け、フォーカスとマウスの振り分け、ショートカット、
## 型つきのバインディング、よく使うウィジェット。端末と話すのは nim-terminal-io。分け方は ADR-TC-0001・0002。

import nim_terminal_core/[geometry, canvas, theme, event, widget, layout, binding, shortcuts, app, lineedit]
export geometry, canvas, theme, event, widget, layout, binding, shortcuts, app, lineedit
import nim_terminal_core/widgets/[label, button, checkbox, textinput, listbox, progressbar]
export label, button, checkbox, textinput, listbox, progressbar

import nim_outcome
export nim_outcome   # 失敗は Outcome で返す (shortcuts.add、app.run)
