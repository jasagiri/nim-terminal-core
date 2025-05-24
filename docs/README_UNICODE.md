# Enhanced Unicode Support in libterminal

This directory contains a comprehensive set of examples demonstrating the advanced Unicode handling capabilities of the `libterminal` library. These examples showcase how the library properly handles various Unicode features, including grapheme clusters, bidirectional text, emoji sequences, and more.

## Quick Start

New to Unicode handling? Check out our [Getting Started with Unicode](docs/UNICODE_GETTING_STARTED.md) guide for a quick introduction to the most important concepts and functions.

## Unicode Capabilities

The `libterminal` library includes the following Unicode-related features:

- **Grapheme Cluster Handling**: Properly treats user-perceived characters (like emoji with skin tones or combining characters) as single entities
- **Accurate Width Calculation**: Correctly calculates the display width of characters across scripts (CJK, Latin, Arabic, etc.)
- **Bidirectional Text Support**: Handles right-to-left languages like Arabic and Hebrew
- **Emoji Support**: Displays emoji characters with proper width calculation, including ZWJ sequences
- **Complex Script Rendering**: Handles Indic, South Asian, and other complex scripts
- **Character Property Detection**: Identifies properties like emoji presentation style
- **Internationalization Support**: Provides functionality for building multilingual applications

## Examples

### 1. Basic Unicode Example (`unicode_example.nim`)

A simple demonstration of basic Unicode support showing various scripts and emoji.

### 2. Enhanced Unicode Example (`enhanced_unicode_example.nim`)

Shows advanced Unicode features like grapheme cluster handling, width calculations, emoji support, and includes a simple animation demo.

### 3. Complex Scripts Example (`complex_scripts_example.nim`)

Focuses on bidirectional text and complex scripts:
- Right-to-left languages (Arabic, Hebrew)
- CJK scripts (Chinese, Japanese, Korean)
- Indic and South Asian scripts
- Mixed script alignment

### 4. Typing Effect Example (`typing_effect_example.nim`)

A real-time typing effect demo that correctly handles:
- Multi-width characters
- Combining characters
- Emoji sequences
- Right-to-left text

### 5. Unicode Tables Example (`unicode_tables_example.nim`)

Demonstrates handling Unicode in structured layouts:
- Table rendering with proper column alignment
- Handling mixed scripts in tabular data
- Comparison of character width properties

### 6. Unicode Benchmark (`unicode_benchmark.nim`)

Measures performance of various Unicode operations:
- Rune conversion and counting
- Grapheme cluster processing
- Width calculations
- Comparison of standard vs. advanced print methods
- Large-scale buffer operations

### 7. Interactive Unicode Demo (`interactive_unicode_demo.nim`)

A comprehensive interactive application with multiple demo modules:
- Unicode information display
- Width calculator for analyzing text
- Emoji explorer organized by categories
- Colored text demonstration across scripts
- Bidirectional text handling showcase

### 8. Unicode Text Editor (`unicode_text_editor.nim`)

A simple text editor that demonstrates proper Unicode handling in a real application:
- Multi-script text editing with proper cursor positioning
- Bidirectional text support
- Unicode character width awareness
- Syntax highlighting for common programming languages

### 9. Unicode Charts and Data Visualization (`unicode_charts_example.nim`)

Shows how to use Unicode characters for data visualization:
- Bar charts using block characters
- Line charts with line drawing characters
- Pie charts with shading characters
- Stacked bar charts
- Heat maps with color gradients

### 10. Internationalization Demo (`i18n_example.nim`)

A demonstration of internationalization and localization features:
- Multilingual support with translations for 9 languages
- Language-specific date and time formatting
- Bidirectional interface for RTL languages
- Proper text alignment based on language direction
- Localized user interface elements

### 11. Unicode Handling Comparison (`unicode_comparison.nim`)

A side-by-side comparison of basic vs. enhanced Unicode handling:
- Visual demonstrations of differences in processing methods
- Interactive visualization of grapheme clusters vs. code points
- Detailed explanation of Unicode handling challenges
- Report generation for documentation
- Practical examples of real-world issues solved by enhanced handling

### 12. Web Showcase Generator (`generate_web_showcase.nim`)

Generates a static HTML showcase for the Unicode capabilities:
- Interactive web-based demonstration of features
- Code examples and explanations
- Screenshot capture support
- Shareable documentation for the library
- Dark/light theme support

### 13. Advanced Unicode Techniques (`advanced_unicode_techniques.nim`)

Demonstrates sophisticated Unicode text handling techniques:
- Intelligent text truncation at grapheme boundaries
- Composite character building with combining marks
- Unicode-aware word boundary detection
- Unicode-aware columnar text layout
- Unicode-aware fuzzy text matching with highlighted results
- Advanced performance optimization techniques
- Incremental text processing for efficiency

### 14. Unicode Performance Strategies (`unicode_performance_strategies.nim`)

Comprehensive benchmarking and optimization strategies for Unicode processing:
- Multi-level caching strategies for Unicode operations
- Partial text processing for large documents
- Lazy evaluation with generators for on-demand processing
- Region-based text processing
- Incremental update techniques
- Real-world performance comparisons
- Optimized data structures for Unicode text handling

### 15. Unicode Composition Example (`unicode_composition_example.nim`)

In-depth exploration of Unicode normalization, composition, and decomposition:
- Unicode normalization forms (NFC, NFD)
- Character composition and decomposition
- Multiple combining marks handling
- Unicode equivalence demonstration
- Character building with combining marks
- String analysis and code point visualization

### 16. Unicode Input Handling (`unicode_input_handling.nim`)

A comprehensive example of Unicode-aware text input handling:
- Grapheme cluster-aware cursor movement and text editing
- Unicode-aware selection operations
- Dead key and composition support for international characters
- Input Method Editor (IME) simulation for non-Latin scripts
- Clipboard operations with proper Unicode handling
- Undo/redo functionality with Unicode awareness

### 17. Bidirectional Text Algorithm (`bidirectional_text_algorithm.nim`)

Complete implementation of the Unicode Bidirectional Algorithm (UAX #9):
- Character type classification for bidirectional processing
- Explicit and implicit level resolution
- Handling of bidirectional control characters
- Visual reordering of mixed direction text
- Interactive bidirectional text demonstration
- Support for complex mixed script examples

### 18. Unicode Collation Algorithm (`unicode_collation.nim`)

Implementation of the Unicode Collation Algorithm (UCA) for linguistically correct string comparison:
- Locale-specific sorting across scripts and languages
- Multi-level collation (primary, secondary, tertiary, quaternary)
- Specialized tailoring rules for languages like Spanish, German, and Swedish
- Character weight visualization and analysis
- Numeric-aware sorting for natural ordering
- Interactive collation tester for comparing strings

### 19. Unicode Regular Expressions (`unicode_regex.nim`)

Unicode-aware regular expression functionality:
- Unicode property support (`\p{Letter}`, `\p{Emoji}`, etc.)
- Support for scripts and character categories across writing systems
- Unicode case-insensitive matching
- Grapheme cluster-aware pattern matching
- Bidirectional text handling in regular expressions
- Interactive regex testing tool

### 20. Unicode Text Segmentation (`unicode_segmentation.nim`)

Implementation of the Unicode text segmentation algorithms (UAX #29, UAX #14):
- Grapheme cluster boundaries for user-perceived character breaks
- Word boundaries for different scripts and languages
- Sentence boundaries with handling of ambiguous punctuation
- Line break opportunities for proper text wrapping
- Comprehensive examples across multiple scripts
- Interactive segmentation demo tool

### 21. Unicode Normalization Forms (`unicode_normalization.nim`)

Demonstrates the Unicode normalization forms and their applications:
- NFD (Canonical Decomposition)
- NFC (Canonical Decomposition followed by Canonical Composition)
- NFKD (Compatibility Decomposition)
- NFKC (Compatibility Decomposition followed by Canonical Composition)
- Canonical equivalence for comparing semantically identical text
- Compatibility equivalence for formatting-agnostic comparison
- Practical applications in string comparison, searching, and storage
- Interactive normalization analyzer

### 22. Unicode Identifiers and Security (`unicode_identifiers.nim`)

Comprehensive guide to Unicode identifier validation and security considerations:
- Implementation of identifier rules for programming languages (UAX #31)
- Domain name and username identifier validation
- Script detection and mixed-script confusable detection
- Protection against homograph attacks and identifier spoofing
- Bidirectional text security and safeguards against hidden code
- Normalization requirements for identifiers across contexts
- Interactive validator for testing identifiers across different rule sets

## Running the Examples

You can run all examples sequentially using the provided script:

```
./run_unicode_examples.sh
```

Or run individual examples directly:

```
nim c -r examples/enhanced_unicode_example.nim
```

To generate a detailed comparison report:

```
nim c -r examples/unicode_comparison.nim --report
```

To generate the web showcase:

```
nim c -r examples/generate_web_showcase.nim
```

After generating the web showcase, you can capture screenshots and complete it:

```
cd unicode_showcase
./capture_screenshots.sh
```

## Key Unicode Utilities

The library includes important Unicode utilities:

### Width Calculation

```nim
proc runeWidth*(r: Rune): int
```
Calculates the display width of a Unicode character (0 for combining characters, 2 for full-width characters like CJK and emoji, 1 for others).

### Grapheme Clusters

```nim
proc splitIntoGraphemeClusters*(text: string): seq[GraphemeCluster]
```
Splits text into grapheme clusters (user-perceived characters).

```nim
proc graphemeLength*(text: string): int
```
Counts the number of grapheme clusters in a string.

```nim
proc displayWidth*(text: string): int
```
Calculates the total display width of a string, respecting grapheme clusters.

### Advanced Printing

```nim
proc printAdvanced*(buffer: var Buffer, x, y: int, text: string, style: Style)
```
Grapheme-aware text printing that handles complex Unicode correctly.

```nim
proc printRGBAdvanced*(buffer: var Buffer, x, y: int, text: string, fgRGB, bgRGB: RGBColor, attrs: set[Attribute] = {})
```
Grapheme-aware text printing with RGB color support.

## Implementation Notes

- Grapheme cluster detection follows the Unicode Standard guidelines (UAX #29)
- Width calculation is based on Unicode East Asian Width property (UAX #11)
- Special handling for zero-width characters, combining marks and emoji modifiers
- Proper handling of ZWJ (Zero Width Joiner) sequences for emoji
- Full Unicode plane support including astral characters
- Bidirectional text handling following the Unicode Bidirectional Algorithm (UAX #9)
- Internationalization support for localized content

## Common Unicode Issues Solved

The `libterminal` library solves these common Unicode text handling issues:

1. **Broken Combining Characters**: Characters like é (e + ́) are kept together
2. **Incorrect Cursor Movement**: Cursor moves by grapheme clusters, not code points
3. **Uneven Text Alignment**: Alignment respects visual width, not character count
4. **Split Emoji**: Complex emoji sequences stay as single units
5. **RTL Text Problems**: Bidirectional text is handled correctly
6. **Width Calculation Errors**: CJK and full-width characters get proper sizing

## Documentation Resources

- **README_UNICODE.md**: This file - main documentation about Unicode support
- **docs/UNICODE_GETTING_STARTED.md**: Quick introduction for beginners
- **docs/UNICODE_GUIDE.md**: Developer guide for implementing Unicode support
- **docs/UNICODE_CHEATSHEET.md**: Quick reference for common Unicode operations
- **unicode_comparison_report.md**: Generated report comparing basic vs. enhanced handling
- **Web Showcase**: Generated HTML showcase for easy sharing and reference

## Getting Started

For developers new to Unicode handling, we provide a beginner-friendly introduction:

[Getting Started with Unicode](docs/UNICODE_GETTING_STARTED.md)

This guide covers:
- Basic setup and first steps
- Common Unicode tasks with code examples
- Essential concepts explained simply
- Common pitfalls and how to avoid them
- Quick solutions for frequent issues

## Developer Guide

For developers looking to implement Unicode support in their own applications, we provide a comprehensive guide:

[Unicode Handling in Terminal Applications](docs/UNICODE_GUIDE.md)

This guide covers:
- Understanding Unicode challenges in terminal applications
- Implementing grapheme cluster detection
- Character width calculation strategies
- Bidirectional text handling approaches
- Emoji and complex script support
- Performance optimization techniques
- Internationalization best practices
- Testing Unicode support effectively

## Quick Reference

For a handy reference of common Unicode operations and solutions to typical issues:

[Unicode Handling Cheat Sheet](docs/UNICODE_CHEATSHEET.md)

This quick reference includes:
- Core function usage examples
- Common character categories
- Best practice code snippets
- Solutions to frequent Unicode issues
- Performance tips
- Special character references

## Useful Resources

- [Unicode Bidirectional Algorithm](https://www.unicode.org/reports/tr9/)
- [Unicode Text Segmentation](https://www.unicode.org/reports/tr29/)
- [Unicode Line Breaking Algorithm](https://www.unicode.org/reports/tr14/)
- [Unicode East Asian Width](https://www.unicode.org/reports/tr11/)
- [Common Locale Data Repository](http://cldr.unicode.org/)
- [Internationalization Best Practices](https://www.w3.org/International/quicktips/)