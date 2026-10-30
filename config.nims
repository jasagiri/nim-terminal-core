# Tasks (`nim <task>`). NimScript, not a Makefile.
#   nim test    every tests/test_*.nim

import std/[algorithm, os, strutils]

proc testsIn(dir: string): seq[string] =
  for f in listFiles(dir):
    let name = f.extractFilename
    if name.startsWith("test_") and name.endsWith(".nim"):
      result.add f
  result.sort()

task test, "Run every tests/test_*.nim":
  # TC-A の E テストが擬似端末の上で起こす
  exec "nim c --hints:off -o:build/run_app tests/run_app.nim"
  exec "nim c --hints:off -o:build/launcher tests/launcher.nim"
  for t in testsIn("tests"):
    exec "nim c -r --hints:off " & quoteShell(t)
