# nim-libterminal Examples

This directory contains comprehensive examples demonstrating the full capabilities of the nim-libterminal project.

## Basic Examples

### Hello World (`hello_world.nim`)
The simplest example showing basic terminal initialization and text output.

### Color Example (`color_example.nim`)
Demonstrates the color system with 16-color, 256-color, and RGB support.

### Signal Handling (`signal_handling.nim`)
Shows proper terminal cleanup and signal handling for robust applications.

### Mouse Example (`mouse_example.nim`)
Interactive demonstration of mouse input handling including clicks, movement, and scrolling.

## Unicode and Text Processing

### Unicode Example (`unicode_example.nim`)
Comprehensive Unicode support including:
- Multi-byte character rendering
- Complex script support
- Bidirectional text (RTL languages)
- Grapheme cluster handling

### Enhanced Unicode (`enhanced_unicode_example.nim`)
Advanced Unicode features:
- Text normalization
- Character composition
- Input method handling
- Performance optimization strategies

## Layout System

### Basic Layout Examples
- Horizontal and vertical layouts
- Grid layouts with responsive sizing
- Nested layout combinations
- Margin and padding management

### Complex Layout Scenarios
- Dynamic resizing
- Percentage-based sizing
- Auto-sizing widgets
- Layout debugging tools

## Widget Framework

### Basic Widgets (`basic_widgets_example.nim`)
Demonstrates all basic widget types:
- **Label**: Static text display with alignment options
- **Button**: Interactive buttons with click handlers
- **TextInput**: Single and multi-line text input
- **Checkbox**: Boolean input with tri-state support
- **ListBox**: Scrollable item selection
- **ProgressBar**: Visual progress indication

### Advanced Widgets
- **Dialog**: Modal dialogs with multiple button configurations
- **Menu**: Dropdown and context menus with nested submenus
- **ScrollView**: Scrollable content areas with automatic scrollbars
- **TabView**: Tabbed interface for organizing content
- **TreeView**: Hierarchical data display with expansion/collapse
- **TableView**: Data tables with sorting, selection, and scrolling

### Tree and Table Example (`tree_table_example.nim`)
Combined demonstration of TreeView and TableView working together to create a file browser-like interface.

## Advanced Features

### Keyboard Shortcuts (`shortcuts_example.nim`)
Complete keyboard shortcut system featuring:
- Global and context-specific shortcuts
- Modifier key combinations (Ctrl, Alt, Shift)
- Shortcut conflicts resolution
- Dynamic shortcut registration
- Context stack management

### Data Binding (`databinding_example.nim`)
Comprehensive data binding system including:
- One-way and two-way binding
- Property value conversion
- Data context management
- Automatic UI updates
- Type-safe property handling

## Practical Applications

### Text Editor (`text_editor.nim`)
A fully functional text editor demonstrating:
- **Menu System**: File, Edit, and Help menus
- **Status Bar**: File name, modification status, cursor position
- **Text Editing**: Multi-line text input with cursor management
- **Keyboard Shortcuts**: Standard editor shortcuts (Ctrl+N, Ctrl+S, etc.)
- **Data Binding**: File state bound to UI elements
- **Modal Dialogs**: Help and confirmation dialogs
- **Event Handling**: Text change notifications

Features:
- New file creation
- File modification tracking
- Position tracking (line/column)
- Context-sensitive help
- Unsaved changes warning

### File Browser (`file_browser.nim`)
A complete file system browser featuring:
- **Directory Navigation**: Tree view of current location
- **File List**: Detailed table view with file information
- **Dual Pane Interface**: Directory tree + file details + info panel
- **Keyboard Navigation**: Arrow keys, Enter, Page Up/Down
- **Quick Actions**: Home directory, parent directory, refresh
- **File Information**: Size, type, permissions display
- **Status Bar**: Current path and item count

Navigation:
- Use arrow keys to browse files
- Enter to navigate into directories
- Ctrl+H for home directory
- Ctrl+U to go up one level
- F5 to refresh current directory

### System Dashboard (`dashboard.nim`)
A comprehensive system monitoring dashboard featuring:
- **Real-time Metrics**: CPU, Memory, Disk usage with progress bars
- **System Information**: Uptime, process count, network statistics
- **Process Monitoring**: Live process list with resource usage
- **Log Viewer**: Real-time system log with different severity levels
- **Interactive Controls**: Pause/resume updates, refresh data, clear logs
- **Auto-refresh**: Configurable automatic data updates
- **Data Visualization**: Progress bars, tables, and formatted metrics

Dashboard Features:
- Live updating metrics (2-second intervals)
- Simulated system data for demonstration
- Keyboard shortcuts for all major functions
- Responsive layout that adapts to terminal size
- Color-coded information and status indicators

## Running the Examples

All examples can be compiled and run using Nim:

```bash
# Basic examples
nim c -r examples/hello_world.nim
nim c -r examples/color_example.nim
nim c -r examples/mouse_example.nim

# Widget framework
nim c -r examples/basic_widgets_example.nim
nim c -r examples/tree_table_example.nim

# Advanced features
nim c -r examples/shortcuts_example.nim
nim c -r examples/databinding_example.nim

# Practical applications
nim c -r examples/text_editor.nim
nim c -r examples/file_browser.nim
nim c -r examples/dashboard.nim
```

## Key Features Demonstrated

### 1. Terminal Control
- Raw mode management with proper cleanup
- Signal handling (Ctrl+C, window resize)
- Terminal size detection and adaptation
- Cross-platform compatibility

### 2. Input Processing
- Keyboard event handling (all key types)
- Mouse input (clicks, movement, scrolling)
- Event queuing and dispatching
- Focus management and tab navigation

### 3. Output and Rendering
- Efficient buffer-based rendering
- Unicode text display and positioning
- Color support (16, 256, RGB)
- Text styling (bold, italic, underline)
- Cursor positioning and visibility

### 4. Widget System
- Object-oriented widget hierarchy
- Event-driven architecture
- Flexible styling and theming
- Layout management (horizontal, vertical, grid)
- State management and persistence

### 5. Advanced Framework Features
- **Shortcuts**: Global and contextual keyboard shortcuts
- **Data Binding**: Reactive UI updates from data changes
- **Dialogs**: Modal and non-modal dialog management
- **Scrolling**: Automatic scrollbar and viewport management
- **Navigation**: Tab-based focus management

## Architecture Highlights

### MECE Design Principle
The library follows the MECE (Mutually Exclusive, Collectively Exhaustive) principle:
- **Low-level Terminal Control**: Raw mode, signals, escape sequences
- **Input Processing**: Keyboard, mouse, event management
- **Output Formatting**: Colors, styles, cursor control
- **High-level Components**: Widgets, layouts, applications

### BDD Development Approach
- Feature specifications in Gherkin format
- Test-driven implementation
- Iterative development with clear milestones
- Comprehensive example coverage

### Nim Language Features
- **Macros and Templates**: DSL creation and code generation
- **Strong Type System**: Compile-time safety and optimization
- **Performance**: Zero-cost abstractions and efficient rendering
- **Exception Handling**: Robust error management
- **Memory Management**: Automatic memory safety

## Getting Started

1. **Start Simple**: Begin with `hello_world.nim` to understand basic concepts
2. **Explore Widgets**: Try `basic_widgets_example.nim` to see available components
3. **Learn Layouts**: Experiment with layout examples for UI organization
4. **Advanced Features**: Explore shortcuts and data binding for complex applications
5. **Real Applications**: Study the text editor, file browser, and dashboard for complete application patterns

Each example is self-contained and thoroughly commented to help you understand both the specific feature being demonstrated and how it fits into the larger framework.

## Next Steps

After exploring these examples, you can:
- Create your own terminal applications using the widget framework
- Extend existing widgets with custom functionality
- Build domain-specific applications (monitoring tools, text processors, games)
- Contribute new widgets or features to the library

The examples progress from simple concepts to complex applications, providing a complete learning path for mastering terminal UI development with Nim.