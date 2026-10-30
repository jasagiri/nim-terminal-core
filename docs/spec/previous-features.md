# 前の版の specs/*.feature と、いまの規則の対応

作り直す前の `specs/*.feature` (jj の履歴の「chore: keep the work in progress before the rebuild」にある) のシナリオを、1 つずつ、いまそれを守る規則に結ぶ。結べないものには「対象外」の理由を書く。端末の層 (色・描画・シグナル・初期化・文字の幅) の規則は、このパッケージではなく nim-terminal-io (ADR-TIO-0001) と nim-unicode-width が持つ。

| 前の feature | シナリオ | いまの規則 |
|---|---|---|
| widget_system | ウィジェットの木を作る | TC L-1、L-9、A-3 |
| widget_system | ウィジェットに見た目を付ける | Theme の役割 (ADR-TC-0001)、W-3、W-12。継承するスタイルは対象外: 役割で引けば、親から受け継ぐ仕組みは要らない |
| widget_system | Tab でフォーカスを移す | TC E-3、W-3 (フォーカスの見た目) |
| widget_system | 事象の手続きを登録して呼ぶ | TC E-1、W-4、W-6、W-13 |
| widget_system | ボタンを押す | TC W-3、W-4 |
| widget_system | 入力欄 | TC W-7〜W-9、T-1〜T-6 |
| widget_system | チェックボックス | TC W-5、W-6 |
| widget_system | 一覧 | TC W-10〜W-13 |
| widget_system | 状態を変えると見た目と手続きが変わる | TC B-1〜B-4、W-1 (bindText)、W-6 (bindChecked) |
| widget_system | 大きさを測り、入れ物の大きさが変わると合わせる | TC L-2、L-9、A-2 |
| widget_system | 事象が親へ伝わる | TC E-1、E-4、E-7 |
| widget_system | ショートカットのキーは、フォーカスが無くても効く | TC K-4、E-2 |
| layout_system | 横に 30% と 70% | TC L-1、L-3 |
| layout_system | 縦に 20%・60%・20% | TC L-1、L-3 |
| layout_system | 3 × 2 の格子 | TC L-5 |
| layout_system | margin と padding | TC L-7 |
| layout_system | 入れ子の割り付け | TC L-9 |
| layout_system | 端末の大きさが変わる | TC L-9、A-2 |
| mouse_input | マウスの報告を入れる | TIO T-8 |
| mouse_input | クリックを読む (位置とボタン) | TIO K-11、TC E-4、E-6 |
| mouse_input | ドラッグを読む | TIO K-11、TC E-5 |
| mouse_input | ホイールを読む | TIO K-11、TC E-7 |
| mouse_input | マウスの報告を切る | TIO T-8 (restore が切る) |
| signal_handling | Ctrl+C | TC E-2 (誰も扱わなければ終わる)、A-1 (SIGINT) |
| signal_handling | 端末の大きさの変更 | TIO T-5、TC A-2 |
| signal_handling | SIGTERM | TC A-1 |
| signal_handling | シグナルの扱いを戻す | TIO T-5 (`stopWatching`)、TC A-1 |
| terminal_initialization | 端末を始める | TIO T-1、T-4、TC A-1 |
| terminal_initialization | 端末を終える | TIO T-4、TC A-1 |
| terminal_initialization | 例外のときに端末を戻す | TC A-1 (どの終わり方でも戻す)。公開の手続きは例外を出さない (`raises: []`) |
| terminal_initialization | Ctrl+C | TC E-2 |
| terminal_initialization | 何度も始めて終える | TIO T-4 (restore は 2 度呼んでよい)、TC A-5 (止めて続ける) |
| advanced_colors | 256 色の端末を見分ける | 対象外: 対象は xterm 系の端末 (foot、Terminal.app、iTerm2、VTE、燈明) で、どれも 256 色と RGB を受ける。terminfo を引くのは要るまで作らない (ADR-TIO-0001 の採らなかった案) |
| advanced_colors | RGB の端末を見分ける | 対象外: 同上 |
| advanced_colors | 256 色を付ける | TIO S-5 |
| advanced_colors | RGB を付ける | TIO S-5 |
| advanced_colors | 基本の色へ落とす | 対象外: 見分けないので落とす先も無い。既定の Theme は 16 色だけを使う |
| efficient_drawing | 前の画面との差分 | TIO S-2、S-3 |
| efficient_drawing | 最小の書き直し | TIO S-4 |
| efficient_drawing | 同じ文字の続きを縮める | 対象外: REP (CSI b) を受けない端末がある。差分 (S-4) で足りる |
| efficient_drawing | スタイルの変更を減らす | 規則は無い。nim-terminal-io の `render` は、スタイルが変わったセルでだけ SGR を書く (実装の振る舞い。番号の規則にするかは nim-terminal-io の判断) |
| efficient_drawing | 全部を書き直す | TIO S-7 |
| unicode_support | 全角 | nim-unicode-width W-3、TIO S-1 |
| unicode_support | 結合文字 | nim-unicode-width W-2、G-4 |
| unicode_support | 絵文字 | nim-unicode-width W-4、K-2、G-6 |
| unicode_support | 文字の幅を数える | nim-unicode-width D-1、W-5 (曖昧な幅) |
| unicode_support | 双方向のテキスト | 対象外: 端末の格子は左から右に置く。並べ替えは端末 (またはその上の表示) の仕事で、TUI の部品は論理の順に書く |
