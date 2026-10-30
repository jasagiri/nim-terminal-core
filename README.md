# nim-libterminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Version](https://img.shields.io/badge/version-0.5.0-blue)
![Nim](https://img.shields.io/badge/nim-2.0%2B-orange)

A production-ready Nim library for terminal manipulation with comprehensive Unicode support, efficient differential drawing, robust error handling, and extensive widget system.

![RGB Color Support](https://img.shields.io/badge/RGB%20Colors-✓-brightgreen)
![256 Colors](https://img.shields.io/badge/256%20Colors-✓-brightgreen)
![Differential Updates](https://img.shields.io/badge/Differential%20Updates-✓-brightgreen)
![Unicode](https://img.shields.io/badge/Unicode-✓-brightgreen)
![Mouse Support](https://img.shields.io/badge/Mouse%20Support-✓-brightgreen)
![Production Ready](https://img.shields.io/badge/Production%20Ready-✓-brightgreen)

## Features

### Core Capabilities
- **🚀 Pure Nim implementation**: Zero external dependencies
- **🌍 Cross-platform**: Linux, macOS, Windows, WASI support
- **⚡ High performance**: Differential updates, optimized rendering
- **🔧 Production ready**: Comprehensive error handling, logging, configuration

### Terminal Control
- **🖥️ Raw mode**: Advanced terminal operations with customizable flags
- **🎨 Rich colors**: Basic, 256-color, and RGB/TrueColor (16.7M colors)
- **🖱️ Mouse support**: Click, drag, scroll events with multiple button support
- **📺 Screen management**: Efficient buffer operations with differential updates

### Text and Unicode
- **🌐 Full Unicode support**: Grapheme clusters, bidirectional text, wide characters
- **✂️ Text processing**: Word wrapping, line breaking, text direction detection
- **📏 Accurate measurement**: Display width calculation for complex scripts

### UI Framework
- **🧩 Widget system**: Labels, buttons, text inputs, progress bars, and more
- **📐 Layout engine**: Flexible horizontal/vertical layouts with constraints
- **🎯 Event handling**: Keyboard and mouse event routing to widgets
- **💾 Data binding**: Reactive UI updates with property binding

### Production Features
- **📊 Structured logging**: Configurable logging with component-specific messages
- **⚙️ Configuration management**: Environment variables, config files, runtime settings
- **🛡️ Error recovery**: Automatic error recovery with fallback strategies
- **📈 Performance monitoring**: Built-in metrics and performance tracking

## Installation

### Via Nimble

```bash
nimble install libterminal
```

### Via Git

```bash
git clone https://github.com/your-org/nim-libterminal.git
cd nim-libterminal
nimble install
```

### In Your Project

Add to your `.nimble` file:

```nim
requires "libterminal >= 0.5.0"
```

## Quick Start

### Simple Terminal App

```nim
import libterminal

# Safe initialization with automatic cleanup
withTerminal:
  clearScreen()
  hideCursor()
  
  # Display styled text
  stdout.setCursorPos(10, 5)
  stdout.write("Hello, Terminal!")
  
  let style = Style(fg: ColorGreen, bg: ColorDefault, attrs: {AttrBold})
  setStyle(style)
  stdout.write("Production Ready!")
  
  # Wait for key press
  discard pollEvent()
  showCursor()
```

### Advanced Usage with Widgets

```nim
import libterminal

proc createUI(): Widget =
  let root = newWidget()
  
  let title = newLabel("My App v1.0")
  title.setRect(Rect(x: 30, y: 2, width: 15, height: 1))
  root.addChild(title)
  
  let button = newButton("Click Me!", proc() = echo "Clicked!")
  button.setRect(Rect(x: 35, y: 10, width: 10, height: 3))
  root.addChild(button)
  
  return root

proc main() =
  # Enable production features
  enableFeature("logging", true)
  setLogLevel("INFO")
  
  withMouseTerminal:
    let ui = createUI()
    let (width, height) = terminalSize()
    var buffer = newBuffer(width, height)
    
    while true:
      # Efficient rendering
      buffer.clear()
      ui.render(buffer)
      buffer.drawBuffer()  # Differential updates
      
      # Event handling
      let event = pollEvent(16)  # 60 FPS
      if event.kind != EvNone:
        if ui.handleEvent(event):
          continue
        if event.kind == EvKey and event.key.key == KeyEscape:
          break

when isMainModule:
  main()
```

## Architecture

nim-libterminal follows a layered architecture:

```
┌─────────────────────────────────────┐
│           Application Layer         │  # Your terminal application
├─────────────────────────────────────┤
│     Widget System & Layout         │  # UI components, layout engine
├─────────────────────────────────────┤  
│    Event System & Input Handling   │  # Keyboard, mouse, resize events
├─────────────────────────────────────┤
│   Output System & Buffer Management │  # Efficient screen rendering
├─────────────────────────────────────┤
│  Terminal Control & Raw Mode        │  # Low-level terminal operations
├─────────────────────────────────────┤
│ Error Handling, Logging, Config     │  # Production infrastructure
└─────────────────────────────────────┘
```

### Design Principles

- **Performance First**: Differential updates, buffer reuse, optimized rendering
- **Unicode Aware**: Proper handling of international text and complex scripts
- **Production Ready**: Comprehensive error handling, logging, and configuration
- **Platform Agnostic**: Consistent behavior across different operating systems
- **Developer Friendly**: Clean APIs with both low-level control and high-level convenience

## Core Features Demo

### Unicode and Internationalization

```nim
# Full Unicode support with proper width calculation
let text = "Hello 世界 🌍 مرحبا"
let width = displayWidth(text)  # Accurate width calculation
let clusters = splitIntoGraphemeClusters(text)  # Proper text segmentation

# Bidirectional text support
let direction = getTextDirection(text)
let visualPos = logicalPosToVisual(text, 5)
```

### Advanced Color Support

```nim
# RGB colors (16.7M colors)
let rgbRed = rgbColor(255, 0, 0)
let rgbBlue = rgbColor(0, 100, 255)

# 256-color palette
let color256 = color256(196)  # Bright red

# Automatic fallback based on terminal capabilities
if supportsColor():
  setColorMode(ColorModeTrueColor)
else:
  setColorMode(ColorModeBasic)
```

### Performance Optimization

```nim
# Differential updates for maximum performance
var buffer = newBuffer(width, height)
buffer.print(10, 5, "Static text", defaultStyle())
buffer.drawBuffer()  # Initial draw

# Only changed areas are redrawn
buffer.print(10, 6, "Updated text", highlightStyle())
buffer.drawBuffer()  # Efficient update
```

## Documentation

### API Documentation
- 📖 **[Complete API Reference](docs/API_REFERENCE.md)** - Comprehensive API documentation
- 🚀 **[Production Deployment Guide](docs/PRODUCTION_GUIDE.md)** - Production best practices
- 📚 **[Examples](examples/)** - Practical usage examples

### Feature Guides
- [Unicode Support](docs/unicode_support.md) - International text handling
- [Color Management](docs/extended_colors.md) - Advanced color features
- [Layout System](docs/layout_system.md) - Widget positioning and sizing
- [Performance Optimization](docs/performance.md) - Speed and efficiency tips

### Integration
- [Error Handling](docs/API_REFERENCE.md#error-handling) - Robust error management
- [Configuration](docs/API_REFERENCE.md#configuration) - Runtime configuration options
- [Logging](docs/API_REFERENCE.md#logging) - Production logging setup

## Production Use

nim-libterminal v0.5.0 is production-ready with:

- ✅ **Comprehensive test suite** - 131+ tests with 100% core coverage
- ✅ **Production error handling** - Structured exceptions with recovery strategies
- ✅ **Performance optimized** - Differential updates, buffer reuse, minimal allocations
- ✅ **Configurable logging** - Structured logging with performance metrics
- ✅ **Environment configuration** - Environment variables and config file support
- ✅ **Cross-platform compatibility** - Linux, macOS, Windows, WASI

### Configuration Example

```bash
# Environment variables for production
export LIBTERMINAL_ENABLE_LOGGING=true
export LIBTERMINAL_LOG_LEVEL=INFO
export LIBTERMINAL_COLOR_SUPPORT=truecolor
export LIBTERMINAL_ENABLE_DIFF_UPDATES=true
```

## Examples

See the [examples/](examples/) directory for:

- **[Basic Usage](examples/hello_world.nim)** - Simple terminal operations
- **[Color Demo](examples/color_example.nim)** - All color modes and styles
- **[Mouse Handling](examples/mouse_example.nim)** - Interactive mouse events  
- **[Unicode Demo](examples/unicode_example.nim)** - International text display
- **[Widget System](examples/basic_widgets_example.nim)** - UI components
- **[Performance](examples/performance_benchmark_example.nim)** - Speed optimization
- **[Production App](examples/advanced_widgets_example.nim)** - Complete application

## Requirements

- **Nim**: 2.0.0 or later
- **Platform**: Linux, macOS, Windows (WSL recommended), WASI
- **Terminal**: Any ANSI-compatible terminal (xterm, GNOME Terminal, iTerm2, Windows Terminal, etc.)

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please see:

- 🐛 **[Issues](https://github.com/your-org/nim-libterminal/issues)** - Bug reports and feature requests
- 🔀 **[Pull Requests](https://github.com/your-org/nim-libterminal/pulls)** - Code contributions
- 💬 **[Discussions](https://github.com/your-org/nim-libterminal/discussions)** - Questions and ideas

## Support

- 📖 **Documentation**: [API Reference](docs/API_REFERENCE.md) and [Production Guide](docs/PRODUCTION_GUIDE.md)
- 💬 **Community**: [Nim Discord](https://discord.gg/nim) #terminal channel
- 🐛 **Issues**: [GitHub Issues](https://github.com/your-org/nim-libterminal/issues)