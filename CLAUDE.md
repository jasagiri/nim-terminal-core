# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is an implementation of a new terminal library for the Nim language. We aim to create a pure Nim terminal manipulation and character-based user interface library that maximizes the features of Nim. The `vendor` directory contains terminal libraries implemented in various languages for reference.

## Development Approach

### BDD Development Process

1. **Specification Writing**:
   - Write specifications for each feature in Gherkin format
   - Specifications serve as both documentation and tests

2. **Test-Driven Development**:
   - Implement tests based on specifications first
   - Then implement features to pass the tests

3. **Iterative Development**:
   - Clearly define next tasks in `TODO.md`
   - Fully implement one feature before moving to the next

### MECE-based Feature Classification

Organize features according to these principles to avoid gaps and overlaps:

1. **Low-level Terminal Control**
2. **Input Processing**
3. **Output Formatting**
4. **High-level Components**

## Design Leveraging Nim Language Features

### Nim Features to Utilize

1. **Macros and Templates**:
   - Utilize for DSL creation
   - Eliminate redundancy through code generation

2. **Strong Type System**:
   - Expressive modeling with algebraic data types
   - Compile-time safety guarantees

3. **Pragmas and Procedure Overloading**:
   - Optimization through inline pragmas
   - Clear API design through overloading

4. **Symbols and NimVM**:
   - Performance improvements through compile-time evaluation
   - Express standard terminal codes using symbols

5. **Exception Handling**:
   - Proper error handling
   - Appropriate terminal state restoration

### Module Structure

```
nim-libterminal/
  |- src/
  |   |- libterminal.nim           # Main module
  |   |- libterminal/
  |       |- private/          # Internal implementation, platform-specific code
  |       |- raw.nim           # Low-level terminal control
  |       |- input.nim         # Input processing (keyboard, mouse)
  |       |- output.nim        # Output processing (colors, styles, cursor)
  |       |- widgets.nim       # High-level widgets
  |       |- layout.nim        # Layout functionality
  |
  |- tests/                    # BDD-style tests
  |- examples/                 # Example code
  |- specs/                    # Gherkin format specifications
```

## Development Instructions

### Build and Test

```bash
# Build the library
nimble build

# Run tests
nimble test

# Install the library
nimble install

# Build using Makefile
make build
make test

# Specific feature tests
make unicode_test
make layout_test

# Compile all examples
make examples
```

### Running Examples

```bash
# Compile and run examples
nim c -r examples/hello_world.nim
nim c -r examples/basic_unicode_test.nim
nim c -r examples/layout_test_simple.nim

# Or use Makefile
make unicode_test
make layout_test
```

## Features to Implement

### 1. Low-level Terminal Control
- Raw mode management
- Terminal cleanup (on exit)
- Terminal size detection
- Signal handling

### 2. Input Processing
- Keyboard events (normal keys, function keys, modifier keys)
- Mouse events (when supported by terminal)
- Window resize events
- Event queue management

### 3. Output Formatting
- Cursor position control
- Color support (16 colors, 256 colors, RGB support)
- Text attributes (bold, italic, underline, etc.)
- Screen clearing and buffer operations
- Unicode support

### 4. High-level Components
- Text layout
- Basic widgets (buttons, text input, etc.)
- Window system
- Event processing and state management

## Architecture and Design Philosophy

### Layered API Design
- **Low-level (raw.nim)**: Terminal control, escape sequences
- **Mid-level (input.nim, output.nim)**: Event processing, buffer management
- **High-level (widgets.nim, layout.nim)**: Widgets, layout system

### Key Technical Elements
- **Differential Update System**: Buffer comparison for efficient screen drawing
- **Unicode Support**: Grapheme clusters and bidirectional text support
- **Event-Driven Architecture**: Integrated mouse/keyboard/signal processing
- **Layout Engine**: Flexible layout system similar to CSS Flexbox

### Widget System
- **widget_base.nim**: Base class for all widgets (Widget)
- **Event Propagation**: Event bubbling based on parent-child relationships
- **Focus Management**: Tab navigation support
- **Data Binding**: Reactive data updates

## Development Notes

- Study reference implementations in the `vendor` directory (especially Rust's termion and crossterm which have clear designs)
- Implement proper error handling for all terminal operations
- Properly restore terminal state even on panic
- Thorough testing with various terminal types
- Detailed API documentation with examples
- Implement low-level API (escape sequences, terminal control) and high-level API (widgets, layout) in separate modules

## Current Implementation Status

See `TODO.md` for detailed progress. Main features implemented:
- Basic terminal control (Raw mode, signal handling)
- Mouse input and keyboard input processing
- Unicode support (grapheme clusters, RTL languages)
- Color support (16 colors, 256 colors, RGB)
- Layout system (horizontal/vertical split, grid)
- Complete set of basic and composite widgets
- Data binding and shortcut system