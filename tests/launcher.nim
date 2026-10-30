## TC-A-5 の起動役: 擬似端末のセッションの長として、アプリを別のプロセスグループで起こして端末の前面を渡す
## (セッションの長の下のグループは孤児になり、カーネルが SIGTSTP を捨てるため)。止まったら "STOPPED" と
## 書き、1 行を読んだら前面を渡し直して続けさせ、終わったら "EXIT n" と書く。

import std/[posix, os, options]
import nim_outcome
import libplatform

proc say(s: string) =
  doAssert posix.write(1, cstring(s & "\r\n"), s.len + 2) == s.len + 2

proc main(): int =
  let own = getpgrp()
  let pid = spawn(SpawnSpec(argv: @[paramStr(1)], group: gcNewGroup)).get
  doAssert giveTerminal(0, pid).isOk
  while true:
    let st = waitChild(pid).get.get
    # 前面を取り戻すのは止まったときと終わったときだけ (再開の知らせで取り上げると、アプリが端末の設定を
    # 変えるところで SIGTTOU を受けて止まる)
    if st.state != csContinued: doAssert giveTerminal(0, own).isOk
    case st.state
    of csStopped:
      say "STOPPED"
      var buf: array[16, char]
      discard posix.read(0, addr buf[0], buf.len)   # Why discard: 1 行を待つだけ
      doAssert giveTerminal(0, pid).isOk
      doAssert signalGroup(pid, SIGCONT).isOk
    of csContinued: discard
    of csExited:
      say "EXIT " & $st.code
      return 0
    of csSignaled:
      say "SIGNAL " & $st.code
      return 0

quit(main())
