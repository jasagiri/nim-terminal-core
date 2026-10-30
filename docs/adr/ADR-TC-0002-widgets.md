# ADR-TC-0002: 行の編集とウィジェット

- 状態: 採用 (2026-10-30)

## コンテキスト
ADR-TC-0001 の枠組みの上に、端末の道具がよく使うウィジェットを置く。前の版のウィジェット (Label・Button・Checkbox・TextInput・ListBox・ProgressBar・ScrollView・Dialog・Menu・TabView・TreeView・TableView) の顔ぶれと、`setOnX` で知らせを受ける形 (ここでは `onX` の手続きの欄) を引き継ぎ、委譲の形で作り直す。行の編集は、TextInput と後のシェル (nim-shell-lang) の両方が使うので、ウィジェットから切り離した `LineEdit` に置く。

## 決定
各ウィジェットは自分の状態を持つ ref object で、`widget` で木に入れる `Widget` を返す。知らせは `onSelect`・`onActivate`・`onChange`・`onClose` などの手続きの欄で受け、`bindX` で `Observable` とつなぐ。見た目は Theme の役割 (`roFocused`・`roSelected` など) で引く。規則は次のとおりで、E テストは規則の番号を名に持つ (`TC-T-*`、`TC-W-*`)。描いた画面を読み戻して確かめる。

### T: 行の編集 (LineEdit)
- **T-1** カーソルは書記素クラスタの境にあり、左右は 1 クラスタずつ動く (全角、絵文字の ZWJ の並び、結合文字)。
- **T-2** 入れる文字のうち、改行・タブは空白にし、ほかの制御文字 (C0、DEL、C1) は捨てる。前の文字とつながる結合文字を入れても、カーソルは境に留まる。
- **T-3** `apply` は文字・貼り付け・矢印・Home・End・Backspace・Delete と、Emacs のキー (C-a C-e C-b C-f C-h C-d C-k C-u C-w、M-b M-f、Ctrl・Alt つきの左右は語の単位) で編集し、`erChanged` (文字が変わった)・`erMoved` (カーソルだけ)・`erIgnored` (編集のキーではない: Enter・Tab・Esc、知らない Ctrl のキー、ASCII でない文字の Ctrl) を返す。
- **T-4** 語は空白で区切る。`killWordBackward` はカーソルの前の空白とその前の語を、`killToEnd`・`killToStart` はカーソルの後ろ・前を消して返す。
- **T-5** `setColumn` は、画面の列に一番近いクラスタの境へカーソルを動かす (幅 2 の文字の右半分なら、その後ろ)。
- **T-6** `column` はカーソルの前の文字の幅 (曖昧な幅の数え方に従う)。

### W: ウィジェット
- **W-1** Label は行ごとに揃えの向き (左・中・右) に置き、`wrap` なら幅で折り返し、そうでなければ幅を越える行を `…` で切る。`bindText` で Observable の値を見せ続ける。
- **W-2** Label の測った大きさは、一番長い行の幅と行の数 (`wrap` なら与えられた幅で折った行の数)。
- **W-3** Button は `[ text ]` と描き、フォーカスがあれば roFocused、マウスで押している間は roAccent。
- **W-4** Button は、フォーカスがあるときの Enter と Space、クリックで `onClick` を呼ぶ。押して外で離したら呼ばない。
- **W-5** Checkbox は `[x] text` か `[ ] text` と描き (フォーカスがあれば印を roFocused)、Space・Enter・クリックで入・切を替える。
- **W-6** Checkbox は変わったときだけ `onChange` を呼ぶ。`bindChecked` は Observable と両向きにつなぐ。
- **W-7** TextInput は文字を描き、空なら placeholder を roMuted で描く。`mask` があれば各クラスタを伏せ字で描く。フォーカスがあれば端末のカーソルをカーソルの所に置く (A-6)。
- **W-8** TextInput は、欄より長い文字をカーソルが見えるよう横に送る。欄の端で切れた幅 2 の文字は空白で描く (C-1)。
- **W-9** TextInput のキーは T-3 で編集し (変われば `onChange`)、Enter で `onSubmit` を呼ぶ。貼り付けは T-2 で入れる。押した列にカーソルを動かす (T-5)。
- **W-10** ListBox の `setItems` は項目を置き換えて指定の項目 (範囲の外は端) を選ぶ。項目が無ければ選びは -1。
- **W-11** ListBox は、選びが変わったとき (と行の数が変わったとき) に、選んだ項目が見えるよう見える範囲を動かす。
- **W-12** ListBox は見えている項目を 1 行ずつ描き、選んだ行は、フォーカスがあれば roSelected、無ければ roSelectedInactive で右の端まで描く。`spans` に触れるクラスタは roMatch (選んだ行では反転を重ねる)。タブは 8 列の境までの空白、ほかの制御文字は `?` (S-6)。
- **W-13** ListBox は上下・PageUp・PageDown・Home・End で選び、Enter で `onActivate`。押した行を選び、ダブルクリックで `onActivate`。ホイールは選びを変えずに 3 行ずつ送り、次に描いても送った所に留まる。
- **W-14** ProgressBar の割合は current / total を 0〜1 に収めたもの。total が 0 以下なら 0。
- **W-15** ProgressBar の残りの見込み (ETA) は、始めてからの平均の速さで決める。進んでいないか時間が経っていないか total が無ければ無い。時計は呼び手が渡す単調な時計。
- **W-16** ProgressBar は `題 [済んだ所と残り] 百分率 ETA` と描く。棒は題と後ろの文字を除いた幅で、済んだセルを roAccent、残りを roMuted で描く (棒の字の幅は数えて描く)。total が無ければ数だけを描く。
- **W-17** ScrollView は中身を、窓の大きさと中身が測った大きさの大きいほうで置き、見えている左上の分だけずらす。溢れた向きには、右の 1 列か下の 1 行に、つまみの付いた棒を描く。
- **W-18** ScrollView の `scrollTo` は中身の端を越えないよう収め、変わったら `onScroll` を呼ぶ。`ensureVisible` は中身の中の子が窓に入るよう送る。
- **W-19** ScrollView はホイール、上下左右、PageUp・PageDown、Home・End で送る。中の子が扱ったキーは送らない (E-1)。
- **W-20** Dialog は枠を描き、上の辺に題を、内に中身 (既定は折り返す message) を、下にボタンを右寄せで並べる。大きさは中身とボタンと題が測った大きさで、画面の中央に置く。
- **W-21** Dialog の `show` は lmModal の層として開き、ボタンを押すとその番号で、Esc で `Cancelled` (-1) で閉じて `onClose` を呼ぶ。閉じると前のフォーカスに戻る (E-8)。
- **W-22** Dialog の中の左右は、ボタンの間でフォーカスを動かす。
- **W-23** Menu は枠の内に項目を 1 行ずつ描き、右に shortcut の案内と、入れ子なら `▸` を描く。選んでいる項目は roSelected、無効の項目は roMuted、区切りは横の線。
- **W-24** Menu は上下 (区切りと無効を飛ばし、端で回る)・Home・End で選び、Enter・Space で動かす。入れ子なら右に開き (右のキーでも)、そうでなければ全部のメニューを閉じてから動作を呼ぶ。押した項目を動かし、押さずに動かすと選ぶ。
- **W-25** Menu の `popup` は lmPopup の層として開く (画面からはみ出すなら内へずらす)。左・Esc・外を押すと閉じ、どの道で閉じても `onClose` を呼ぶ。
- **W-26** MenuBar は題を 1 行に並べ、左右で題を選び、Enter・下・押すで、その題の下にメニューを開く。開いたメニューの中の左右 (入れ子の無い項目で) は隣の題のメニューへ移る。
- **W-27** TabView は帯に題を並べ (選んだ題は roAccent、帯にフォーカスがあれば roSelected)、閉じられる題には `×` を付け、選んだ題の中身だけを見えるようにする (隠れた中身にはフォーカスが行かない。E-9)。
- **W-28** TabView は、帯にフォーカスがあれば左右で、中のどこからでも Ctrl+PageUp・Ctrl+PageDown で題を移り、変わったら `onTabChange` を呼ぶ。題を押すと選ぶ。
- **W-29** TabView の `×` を押すか `removeTab` で題を除き、`onTabClose` を呼ぶ。選んでいた題なら、同じ位置 (末尾なら前) の題を選ぶ。
- **W-30** TreeView は開いている節の子を前順に、深さ × `indent` だけ字下げし、印 (開いた・閉じた・葉) と文字を描く。選んだ行は W-12 と同じに描く。
- **W-31** TreeView の `expand` は先に `onExpand` を呼び (そこで子を読み込める)、子が無ければ開かない。`collapse` は、選んでいた子孫から閉じた節へ選びを移す。
- **W-32** TreeView は上下・PageUp・PageDown・Home・End で選ぶ。右は閉じていれば開き、開いていれば最初の子へ。左は開いていれば閉じ、閉じていれば親へ。Space で開け閉め、Enter で `onActivate`。押すと選び、印を押すと開け閉め、ダブルクリックで `onActivate`。ホイールは選びを変えずに送る。
- **W-33** TableView は 1 行目に見出しを roHeader で (並べ替えた列には ▲ か ▼ を付けて) 描き、その下に行を描く。列の幅は列の制約を L-2 で割り付けて決め (`natural` は見出しと中身の一番長い幅)、列の間を 1 列あける。セルは幅に収めて揃える。
- **W-34** TableView の `sortBy` はその列の文字で並べ替え (同じ文字の行は前の順を保つ)、選んでいた行を並べ替えた後も選ぶ。`onSort` があれば並べ替えはそれに任せる。
- **W-35** TableView は上下・PageUp・PageDown・Home・End で選び、Enter で `onActivate`。行を押すと選び、ダブルクリックで `onActivate`。見出しを押すとその列で並べ替え、同じ列なら向きを替える。ホイールで送る。

### 大きさの制約の既定
- 大きさの制約 (`Constraint`) は親の並びの向きの長さなので、横にも縦にも置けるウィジェットの既定は `natural` にする (縦の箱では測った行の数、横の箱では測った幅)。TextInput を横の箱で使うときは、呼び手が `fill` か `fixed` で幅を決める。2026-10-30 に例 (examples/form.nim) を tmux の上で動かして、`fixed(1)` の既定が横の箱で欄を 1 列に潰すのを見つけた。

## 採らなかった案
- **ProgressBar の Gradient と Animated の形** (terminal-ui/progress_bar.nim): 動きは頼まれたときだけ足す (開発の規則)。色は Theme の役割で決める。
- **ProgressBar の時計に cpuTime** (progress_bar.nim): CPU の時間は待っている間に進まず、ETA が短く出る。単調な時計を呼び手が渡す。
- **TableView のセルの選び** (前の版の TableSelection): 行を選べば足りる。要るときに足す。
- **ScrollView が中のフォーカスに合わせて自分で送る**: evFocusIn は本人にだけ届く。いまは `ensureVisible` を呼び手が呼ぶ。要れば、フォーカスの移りを祖先に知らせる口を枠組み (ADR-TC-0001) に足す。
- **ウィジェットの中の pointer のデータ** (前の版の TreeNode・TableView の data: pointer): 型が無い。TreeNode は `id`、TableView は行の位置で呼び手のデータを引く。
