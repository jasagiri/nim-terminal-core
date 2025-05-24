# Package

version       = "0.0.0"
author        = "jasagiri"
description   = "A pure Nim terminal manipulation library"
license       = "Apache-2.0"
srcDir        = "src"

# Dependencies

requires "nim >= 2.2.0"

# Agent integration dependencies are part of standard library
# No additional dependencies required for basic agent functionality

# requires "https://github.com/jasagiri/nim-lang-core.git"
# requires "https://github.com/jasagiri/nim-libaspects.git"
# requires "https://github.com/jasagiri/nim-design-patterns.git"

# requires "https://github.com/Gods-Golem-Inc/cusinart-runtime.git"

# Tests

task test, "Run tests":
  exec "nim c -d:noAgents -r tests/test_all"

task testci, "Run tests in CI mode (skip terminal tests)":
  exec "nim c -d:noAgents -d:skipTerminalTests -r tests/test_all"

# Examples

task examples, "Build and run examples":
  exec "nim c -r examples/hello_world"

task agentExample, "Build and run agent integration example":
  exec "nim c -r examples/agent_terminal_example"

# Documentation

task docs, "Generate documentation":
  exec "nim doc --project --index:on --outdir:docs src/libterminal.nim"
