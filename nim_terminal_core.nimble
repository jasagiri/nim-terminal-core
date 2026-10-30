# Package

version       = "0.5.0"
author        = "jasagiri"
description   = "nim-terminal-core: Production-ready Nim terminal manipulation library with Unicode support, efficient drawing, and comprehensive error handling"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

# Optional dependencies for enhanced features
# None required - this is a zero-dependency library!

# Agent integration dependencies are part of standard library
# No additional dependencies required for basic agent functionality

# requires "https://github.com/jasagiri/nim-lang-core.git"
# requires "https://github.com/jasagiri/nim-libaspects.git"
# requires "https://github.com/jasagiri/nim-design-patterns.git"

# requires "https://github.com/Gods-Golem-Inc/cusinart-runtime.git"

# Tests and Development

task test, "Run all tests":
  exec "nim c -d:test -d:noAgents -r tests/test_all"

task testci, "Run tests in CI mode (skip flakey tests)":
  exec "nim c -d:test -d:noAgents -d:skipFlakeyTests -r tests/test_all"

task testquick, "Run quick tests only":
  exec "nim c -d:test -d:noAgents tests/test_all && echo 'Compilation successful'"

task test_with_coverage, "Run tests with coverage":
  exec "nim c -d:test -d:noAgents --debugger:native --passC:--coverage --passL:--coverage -r tests/test_all"
  exec "gcov tests/test_all"
  exec "lcov --capture --directory . --output-file coverage.info"
  exec "lcov --remove coverage.info '/usr/*' '*/nimcache/*' --output-file coverage.info"
  exec "lcov --extract coverage.info '*/src/nim_terminal_core/*' --output-file project_coverage.info"
  exec "lcov --list project_coverage.info"
  exec "genhtml project_coverage.info --output-directory coverage_report --ignore-errors range"
  echo "Coverage report generated in coverage_report/index.html"

task coverage, "Generate test coverage report":
  exec "nimble test_with_coverage"

task benchmark, "Run performance benchmarks":
  exec "nim c -d:release -r examples/performance_benchmark_example"

task clean, "Clean build artifacts":
  rmDir "nimcache"
  rmFile "tests/test_all"
  for file in listFiles("."):
    if file.endsWith(".out") or file.endsWith(".exe"):
      rmFile file

task test_9p, "Run tests with 9P support":
  exec "nim c -d:test -d:ninep -r tests/test_all"

# Examples

task examples, "Build and run examples":
  exec "nim c -r examples/hello_world"

task agentExample, "Build and run agent integration example":
  exec "nim c -r examples/agent_terminal_example"

# Documentation

task docs, "Generate API documentation":
  exec "nim doc --project --index:on --outdir:docs/api src/nim_terminal_core.nim"
  echo "Documentation generated in docs/api/"

task release, "Prepare release build":
  echo "Building release version..."
  exec "nim c -d:release --opt:speed src/nim_terminal_core.nim"
  exec "nimble test"
  exec "nimble benchmark"
  echo "Release build complete!"

task install_dev, "Install development dependencies":
  echo "Installing development tools..."
  # No external dependencies needed - pure Nim!
  echo "nim-terminal-core is dependency-free!"

task validate, "Validate package for release":
  echo "Validating package..."
  exec "nimble test"
  exec "nim check src/nim_terminal_core.nim"
  exec "nimble testci"  # Test CI compatibility
  echo "Package validation complete!"
