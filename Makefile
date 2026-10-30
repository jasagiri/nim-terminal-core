# Nim Terminal Library Makefile

.PHONY: build clean test unicode_test

# Default build target
build:
	nimble build

# Clean build artifacts
clean:
	nimble clean

# Run all tests
test:
	nimble test

# Run the Unicode test
unicode_test:
	nim c -r examples/basic_unicode_test.nim

# Run the layout test
layout_test:
	nim c -r examples/layout_test_simple.nim

# Compile the examples
examples:
	nim c examples/basic_colors.nim
	nim c examples/hello_world.nim
	nim c examples/simple_color_example.nim
	nim c examples/basic_unicode_test.nim
	nim c examples/layout_test_simple.nim
	nim c examples/actor_app_example.nim
	nim c examples/actor_metrics_example.nim

# Build with 9P support examples
actor_example:
	nim c -r examples/actor_app_example.nim

metrics_example:
	nim c -r examples/actor_metrics_example.nim

# Build without 9P support
metrics_example_no9p:
	nim c -d:no9p -r examples/actor_metrics_example.nim

# Help information
help:
	@echo "Nim Terminal Library Makefile Commands:"
	@echo "  make build              - Build the library"
	@echo "  make clean              - Clean build artifacts"
	@echo "  make test               - Run all tests"
	@echo "  make unicode_test       - Run the Unicode test"
	@echo "  make layout_test        - Run the layout system test"
	@echo "  make examples           - Compile all examples"
	@echo "  make actor_example      - Run actor-based app example"
	@echo "  make metrics_example    - Run metrics example with 9P"
	@echo "  make metrics_example_no9p - Run metrics example without 9P"
	@echo "  make help               - Show this help information"