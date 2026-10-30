#!/bin/bash
# Run all the Unicode-related examples to demonstrate enhanced Unicode support

echo "==== libterminal Unicode Examples ===="
echo

# Compile all examples
echo "Compiling examples..."
echo "----------------------"
nim c -r:off examples/unicode_example.nim
nim c -r:off examples/enhanced_unicode_example.nim 
nim c -r:off examples/complex_scripts_example.nim
nim c -r:off examples/typing_effect_example.nim
nim c -r:off examples/unicode_tables_example.nim
nim c -r:off examples/unicode_benchmark.nim
nim c -r:off examples/interactive_unicode_demo.nim
nim c -r:off examples/unicode_text_editor.nim
nim c -r:off examples/unicode_charts_example.nim
nim c -r:off examples/i18n_example.nim
nim c -r:off examples/unicode_comparison.nim
nim c -r:off examples/generate_web_showcase.nim

# Compile new advanced examples
nim c -r:off examples/advanced_unicode_techniques.nim
nim c -r:off examples/unicode_performance_strategies.nim
nim c -r:off examples/unicode_composition_example.nim
nim c -r:off examples/unicode_input_handling.nim
nim c -r:off examples/bidirectional_text_algorithm.nim
nim c -r:off examples/unicode_collation.nim
nim c -r:off examples/unicode_regex.nim
nim c -r:off examples/unicode_segmentation.nim
nim c -r:off examples/unicode_normalization.nim
nim c -r:off examples/unicode_identifiers.nim
echo

# Run each example
echo "Running examples:"
echo "-----------------"
echo "1. Basic Unicode Example"
echo "Press any key to run..."
read -n 1
./examples/unicode_example
echo

echo "2. Enhanced Unicode Example"
echo "Press any key to run..."
read -n 1
./examples/enhanced_unicode_example
echo

echo "3. Complex Scripts Example"
echo "Press any key to run..."
read -n 1
./examples/complex_scripts_example
echo

echo "4. Typing Effect Example"
echo "Press any key to run..."
read -n 1
./examples/typing_effect_example
echo

echo "5. Unicode Tables Example"
echo "Press any key to run..."
read -n 1
./examples/unicode_tables_example
echo

echo "6. Unicode Benchmark"
echo "Press any key to run..."
read -n 1
./examples/unicode_benchmark
echo

echo "7. Interactive Unicode Demo"
echo "Press any key to run..."
read -n 1
./examples/interactive_unicode_demo
echo

echo "8. Unicode Text Editor"
echo "Press any key to run..."
read -n 1
./examples/unicode_text_editor
echo

echo "9. Unicode Charts and Data Visualization"
echo "Press any key to run..."
read -n 1
./examples/unicode_charts_example
echo

echo "10. Internationalization and Localization Demo"
echo "Press any key to run..."
read -n 1
./examples/i18n_example
echo

echo "11. Unicode Handling Comparison"
echo "Press any key to run..."
read -n 1
./examples/unicode_comparison
echo

# Generate the comparison report
echo "Generating Unicode Comparison Report..."
./examples/unicode_comparison --report

# Generate the web showcase
echo "Generating Web Showcase..."
./examples/generate_web_showcase

echo "12. Advanced Unicode Techniques"
echo "Press any key to run..."
read -n 1
./examples/advanced_unicode_techniques
echo

echo "13. Unicode Performance Strategies"
echo "Press any key to run..."
read -n 1
./examples/unicode_performance_strategies
echo

echo "14. Unicode Composition and Normalization"
echo "Press any key to run..."
read -n 1
./examples/unicode_composition_example
echo

echo "15. Unicode Input Handling"
echo "Press any key to run..."
read -n 1
./examples/unicode_input_handling
echo

echo "16. Bidirectional Text Algorithm"
echo "Press any key to run..."
read -n 1
./examples/bidirectional_text_algorithm
echo

echo "17. Unicode Collation Algorithm"
echo "Press any key to run..."
read -n 1
./examples/unicode_collation
echo

echo "18. Unicode Regex Support"
echo "Press any key to run..."
read -n 1
./examples/unicode_regex
echo

echo "19. Unicode Text Segmentation"
echo "Press any key to run..."
read -n 1
./examples/unicode_segmentation
echo

echo "20. Unicode Normalization Forms"
echo "Press any key to run..."
read -n 1
./examples/unicode_normalization
echo

echo "21. Unicode Identifiers and Security"
echo "Press any key to run..."
read -n 1
./examples/unicode_identifiers
echo

echo "Unicode examples completed!"
echo "A comparison report has been generated: unicode_comparison_report.md"
echo "A web showcase has been generated in: unicode_showcase/"
echo "  Run 'cd unicode_showcase && ./capture_screenshots.sh' to complete the showcase with screenshots."