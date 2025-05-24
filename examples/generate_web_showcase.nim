# generate_web_showcase.nim
## Web Showcase Generator
## 
## This tool generates a web-based showcase of libterminal's Unicode capabilities
## using screenshots of examples and documentation from README_UNICODE.md.
## It creates a static HTML page that can be easily shared or embedded in documentation.

import std/os
import std/strutils
import std/times

# HTML template for the showcase
const htmlTemplate = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>libterminal Unicode Capabilities</title>
  <style>
    :root {
      --primary-color: #6a5acd;
      --secondary-color: #4b3d93;
      --text-color: #333;
      --background-color: #f9f9f9;
      --card-bg: #fff;
      --code-bg: #f0f0f0;
      --header-bg: #6a5acd;
      --header-text: #fff;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --primary-color: #8b7ddd;
        --secondary-color: #6a5acd;
        --text-color: #e0e0e0;
        --background-color: #1a1a1a;
        --card-bg: #2d2d2d;
        --code-bg: #333;
        --header-bg: #4b3d93;
        --header-text: #fff;
      }
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
      line-height: 1.6;
      color: var(--text-color);
      background-color: var(--background-color);
      margin: 0;
      padding: 0;
    }

    .container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 20px;
    }

    header {
      background-color: var(--header-bg);
      color: var(--header-text);
      padding: 30px 0;
      text-align: center;
      margin-bottom: 40px;
    }

    header h1 {
      margin: 0;
      font-size: 2.5rem;
    }

    header p {
      font-size: 1.2rem;
      margin: 10px 0 0;
      opacity: 0.9;
    }

    .features {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
      gap: 30px;
      margin-bottom: 50px;
    }

    .feature-card {
      background-color: var(--card-bg);
      border-radius: 8px;
      box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
      padding: 20px;
      transition: transform 0.3s ease, box-shadow 0.3s ease;
    }

    .feature-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 16px rgba(0, 0, 0, 0.15);
    }

    .feature-card h3 {
      color: var(--primary-color);
      margin-top: 0;
      border-bottom: 2px solid var(--primary-color);
      padding-bottom: 10px;
    }

    .example-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(450px, 1fr));
      gap: 40px;
      margin-bottom: 50px;
    }

    .example-card {
      background-color: var(--card-bg);
      border-radius: 8px;
      box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
      padding: 20px;
      display: flex;
      flex-direction: column;
    }

    .example-card h3 {
      color: var(--primary-color);
      margin-top: 0;
    }

    .example-image {
      width: 100%;
      height: auto;
      border-radius: 4px;
      margin-bottom: 10px;
      border: 1px solid #ddd;
    }

    pre {
      background-color: var(--code-bg);
      padding: 15px;
      border-radius: 5px;
      overflow-x: auto;
    }

    code {
      font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
      font-size: 0.9rem;
    }

    .section-title {
      text-align: center;
      margin: 50px 0 30px;
      color: var(--primary-color);
    }

    .button {
      display: inline-block;
      background-color: var(--primary-color);
      color: white;
      padding: 10px 20px;
      text-decoration: none;
      border-radius: 5px;
      font-weight: bold;
      transition: background-color 0.3s;
    }

    .button:hover {
      background-color: var(--secondary-color);
    }

    footer {
      text-align: center;
      margin-top: 50px;
      padding: 20px;
      background-color: var(--header-bg);
      color: var(--header-text);
    }
    
    .animation-container {
      width: 100%;
      height: 150px;
      border: 1px solid #ddd;
      border-radius: 4px;
      margin: 20px 0;
      background-color: var(--code-bg);
      overflow: hidden;
      position: relative;
    }
    
    .animation-text {
      position: absolute;
      white-space: nowrap;
      font-family: monospace;
      font-size: 16px;
      animation: typewriter 8s linear infinite;
    }
    
    @keyframes typewriter {
      0% { left: 100%; }
      100% { left: -100%; }
    }
    
    #emoji-animation .animation-text {
      font-size: 24px;
    }
    
    #bidi-animation .animation-text {
      font-size: 18px;
    }
    
    .tab-container {
      margin: 20px 0;
    }
    
    .tabs {
      display: flex;
      list-style: none;
      padding: 0;
      margin: 0;
      border-bottom: 2px solid var(--primary-color);
    }
    
    .tab {
      padding: 10px 20px;
      cursor: pointer;
      background-color: var(--code-bg);
      border-top-left-radius: 6px;
      border-top-right-radius: 6px;
      margin-right: 5px;
    }
    
    .tab.active {
      background-color: var(--primary-color);
      color: white;
    }
    
    .tab-content {
      display: none;
      padding: 20px;
      background-color: var(--card-bg);
      border-bottom-left-radius: 6px;
      border-bottom-right-radius: 6px;
      border: 1px solid #ddd;
      border-top: none;
    }
    
    .tab-content.active {
      display: block;
    }
  </style>
</head>
<body>
  <header>
    <div class="container">
      <h1>libterminal Unicode Capabilities</h1>
      <p>Advanced Unicode support for terminal applications</p>
    </div>
  </header>

  <div class="container">
    <h2 class="section-title">Key Features</h2>
    
    <div class="features">
      <div class="feature-card">
        <h3>Grapheme Cluster Handling</h3>
        <p>Properly treats user-perceived characters (like emoji with skin tones or combining characters) as single entities, ensuring correct cursor movement and text editing.</p>
        <div class="animation-container">
          <div class="animation-text">é (e + ́) → é | Z̸̈ → Z̸̈ | 👨‍👩‍👧‍👦 → 👨‍👩‍👧‍👦</div>
        </div>
      </div>
      
      <div class="feature-card">
        <h3>Accurate Width Calculation</h3>
        <p>Correctly calculates the display width of characters across scripts (CJK, Latin, Arabic, etc.), ensuring proper text alignment and layout.</p>
        <div class="animation-container">
          <div class="animation-text">A(1) 文(2) ♥️(2) ñ(1) 한(2) é(1) म(1) ا(1)</div>
        </div>
      </div>
      
      <div class="feature-card">
        <h3>Bidirectional Text Support</h3>
        <p>Handles right-to-left languages like Arabic and Hebrew, with proper mixing of RTL and LTR content.</p>
        <div class="animation-container" id="bidi-animation">
          <div class="animation-text">English مرحبا بالعالم and שלום עולם mixed with 你好</div>
        </div>
      </div>
      
      <div class="feature-card">
        <h3>Emoji Support</h3>
        <p>Displays emoji characters with proper width calculation, including ZWJ sequences, skin tone modifiers, and emoji variation selectors.</p>
        <div class="animation-container" id="emoji-animation">
          <div class="animation-text">😀 👨‍👩‍👧‍👦 🏳️‍🌈 👩‍🔬 🇯🇵 👍🏽 🚀 🌍</div>
        </div>
      </div>
      
      <div class="feature-card">
        <h3>Complex Script Rendering</h3>
        <p>Handles Indic, South Asian, and other complex scripts, ensuring proper character display and cursor positioning.</p>
      </div>
      
      <div class="feature-card">
        <h3>Internationalization Support</h3>
        <p>Provides functionality for building fully multilingual applications, including text direction, locale formatting, and translations.</p>
      </div>
    </div>

    <h2 class="section-title">Example Showcase</h2>
    
    <div class="example-grid">
      $EXAMPLES$
    </div>

    <h2 class="section-title">Code Examples</h2>
    
    <div class="tab-container">
      <ul class="tabs">
        <li class="tab active" onclick="openTab(event, 'tab1')">Grapheme Clusters</li>
        <li class="tab" onclick="openTab(event, 'tab2')">Width Calculation</li>
        <li class="tab" onclick="openTab(event, 'tab3')">Bidirectional Text</li>
        <li class="tab" onclick="openTab(event, 'tab4')">Advanced Printing</li>
        <li class="tab" onclick="openTab(event, 'tab5')">Internationalization</li>
      </ul>
      
      <div id="tab1" class="tab-content active">
        <h3>Working with Grapheme Clusters</h3>
        <p>Splitting text into grapheme clusters and getting their properties:</p>
        <pre><code>import libterminal
import std/unicode

# Split text into grapheme clusters
let text = "Café 👨‍👩‍👧‍👦 你好"
let clusters = unicode_utils.splitIntoGraphemeClusters(text)

for cluster in clusters:
  echo "Cluster: ", cluster.codePoints.mapIt($it).join(", ")
  echo "Width: ", cluster.width
  echo "Is emoji: ", cluster.isEmoji
  echo "---"

# Count grapheme clusters (user-perceived characters)
let count = unicode_utils.graphemeLength(text)
echo "Grapheme count: ", count
echo "Character count: ", text.runeLen  # Standard Unicode code points</code></pre>
      </div>
      
      <div id="tab2" class="tab-content">
        <h3>Unicode Width Calculation</h3>
        <p>Calculating display width correctly across scripts:</p>
        <pre><code>import libterminal
import std/unicode

# Get width of individual characters
echo "Width of 'A': ", runeWidth('A'.Rune)          # 1
echo "Width of '文': ", runeWidth('文'.Rune)        # 2
echo "Width of '👍': ", runeWidth('👍'.Rune)        # 2
echo "Width of combining ́: ", runeWidth('́'.Rune)    # 0

# Calculate total display width of strings
let text1 = "Hello world"              # Latin
let text2 = "你好世界"                  # CJK
let text3 = "مرحبا بالعالم"            # Arabic
let text4 = "안녕하세요 세계"            # Korean

echo "Width of '", text1, "': ", displayWidth(text1)  # 11
echo "Width of '", text2, "': ", displayWidth(text2)  # 8 (4 chars * 2)
echo "Width of '", text3, "': ", displayWidth(text3)  # 13
echo "Width of '", text4, "': ", displayWidth(text4)  # 13</code></pre>
      </div>
      
      <div id="tab3" class="tab-content">
        <h3>Handling Bidirectional Text</h3>
        <p>Properly displaying and processing mixed RTL/LTR text:</p>
        <pre><code>import libterminal
import std/unicode

# Check text direction
proc getTextDirection(text: string): string =
  # Simple heuristic - check first strong directional character
  for r in text.toRunes:
    let cp = r.int32
    if (cp >= 0x0590 and cp <= 0x08FF) or   # Hebrew/Arabic ranges
       (cp >= 0xFB1D and cp <= 0xFDFF) or
       (cp >= 0xFE70 and cp <= 0xFEFF):
      return "RTL"
  return "LTR"

# Print with correct direction handling
proc printBidirectionalText(buffer: var Buffer, x, y: int, text: string) =
  let direction = getTextDirection(text)
  
  if direction == "RTL":
    # For RTL text, calculate width and right-align
    let width = displayWidth(text)
    buffer.printAdvanced(x + width, y, text, Style())
  else:
    # For LTR text, print normally
    buffer.printAdvanced(x, y, text, Style())</code></pre>
      </div>
      
      <div id="tab4" class="tab-content">
        <h3>Advanced Unicode-aware Printing</h3>
        <p>Using the enhanced print functions for proper Unicode handling:</p>
        <pre><code>import libterminal
import std/unicode

proc main() =
  withTerminal:
    let (width, height) = raw.getTerminalSize()
    var buffer = newBuffer(width, height)
    
    # Basic print (character by character)
    buffer.print(2, 3, "Basic: Hello 你好 👍 é", Style())
    
    # Advanced print (grapheme cluster aware)
    buffer.printAdvanced(2, 5, "Advanced: Hello 你好 👍 é", Style())
    
    # Advanced print with RGB colors for mixed scripts
    let textStyle = Style(fg: ColorDefault, bg: ColorDefault)
    buffer.printRGBAdvanced(2, 7, "English", RGBColor(r: 255, g: 100, b: 100), RGBColor(r: 0, g: 0, b: 0))
    buffer.printRGBAdvanced(10, 7, "日本語", RGBColor(r: 100, g: 255, b: 100), RGBColor(r: 0, g: 0, b: 0))
    buffer.printRGBAdvanced(18, 7, "العربية", RGBColor(r: 100, g: 100, b: 255), RGBColor(r: 0, g: 0, b: 0))
    buffer.printRGBAdvanced(28, 7, "Emoji→🌈🦄✨", RGBColor(r: 255, g: 200, b: 50), RGBColor(r: 0, g: 0, b: 0))
    
    drawBuffer(buffer)
    discard input.pollEvent()</code></pre>
      </div>
      
      <div id="tab5" class="tab-content">
        <h3>Internationalization Support</h3>
        <p>Building multilingual applications with proper localization:</p>
        <pre><code>import libterminal
import std/tables
import std/times

type
  Language = enum
    English, Japanese, Arabic, Spanish

# Translations table
let translations = {
  English: {
    "welcome": "Welcome",
    "settings": "Settings",
    "exit": "Exit"
  }.toTable,
  
  Japanese: {
    "welcome": "ようこそ",
    "settings": "設定",
    "exit": "終了"
  }.toTable,
  
  Arabic: {
    "welcome": "مرحباً",
    "settings": "إعدادات",
    "exit": "خروج"
  }.toTable,
  
  Spanish: {
    "welcome": "Bienvenido",
    "settings": "Configuración",
    "exit": "Salir"
  }.toTable
}.toTable

# Format date based on locale
proc formatDate(dt: DateTime, lang: Language): string =
  case lang
  of English:
    return dt.format("MMMM d, yyyy")
  of Japanese:
    return dt.format("yyyy年MM月dd日")
  of Arabic:
    # Simplified Arabic date format
    return dt.format("yyyy/MM/dd")
  of Spanish:
    return dt.format("d 'de' MMMM 'de' yyyy")

# Get text for current language
proc getText(key: string, lang: Language): string =
  if translations[lang].hasKey(key):
    return translations[lang][key]
  return key</code></pre>
      </div>
    </div>

    <h2 class="section-title">Getting Started</h2>
    
    <div class="feature-card">
      <h3>Installation</h3>
      <p>Add libterminal to your Nim project:</p>
      <pre><code>nimble install libterminal</code></pre>
      <p>Or add to your .nimble file:</p>
      <pre><code>requires "libterminal >= 1.0.0"</code></pre>
      <p><a href="https://github.com/example/libterminal" class="button">View on GitHub</a></p>
    </div>

  </div>

  <footer>
    <div class="container">
      <p>libterminal - Advanced Unicode Terminal Library for Nim</p>
      <p>Generated on $DATE$</p>
    </div>
  </footer>

  <script>
    function openTab(evt, tabName) {
      var i, tabcontent, tablinks;
      
      // Hide all tab content
      tabcontent = document.getElementsByClassName("tab-content");
      for (i = 0; i < tabcontent.length; i++) {
        tabcontent[i].className = tabcontent[i].className.replace(" active", "");
      }
      
      // Remove active class from all tabs
      tablinks = document.getElementsByClassName("tab");
      for (i = 0; i < tablinks.length; i++) {
        tablinks[i].className = tablinks[i].className.replace(" active", "");
      }
      
      // Show the current tab and mark it as active
      document.getElementById(tabName).className += " active";
      evt.currentTarget.className += " active";
    }
  </script>
</body>
</html>
"""

# Example cards template
const exampleCardTemplate = """
      <div class="example-card">
        <h3>$TITLE$</h3>
        <p>$DESCRIPTION$</p>
        <img src="$IMAGE_PATH$" alt="$TITLE$" class="example-image">
        <p><small>$COMMAND$</small></p>
      </div>
"""

# Function to create image placeholder text for each example
proc createExampleCards(): string =
  let examples = [
    (
      title: "Enhanced Unicode Rendering",
      description: "Proper rendering of grapheme clusters, combining characters, and emoji sequences.",
      imagePath: "screenshots/enhanced_unicode.png",
      command: "nim c -r examples/enhanced_unicode_example.nim"
    ),
    (
      title: "Complex Scripts Support",
      description: "Handling of RTL languages and complex scripts with proper alignment.",
      imagePath: "screenshots/complex_scripts.png",
      command: "nim c -r examples/complex_scripts_example.nim"
    ),
    (
      title: "Unicode Typing Effects",
      description: "Real-time typing effects with correct grapheme handling across scripts.",
      imagePath: "screenshots/typing_effect.png",
      command: "nim c -r examples/typing_effect_example.nim"
    ),
    (
      title: "Unicode Tables",
      description: "Structured layouts with proper column alignment for mixed scripts.",
      imagePath: "screenshots/unicode_tables.png",
      command: "nim c -r examples/unicode_tables_example.nim"
    ),
    (
      title: "Internationalization",
      description: "Multilingual support with proper localization and text direction.",
      imagePath: "screenshots/i18n_example.png",
      command: "nim c -r examples/i18n_example.nim"
    ),
    (
      title: "Unicode Text Editor",
      description: "A fully-featured text editor with proper Unicode cursor placement.",
      imagePath: "screenshots/unicode_text_editor.png",
      command: "nim c -r examples/unicode_text_editor.nim"
    ),
    (
      title: "Unicode Data Visualization",
      description: "Charts and data visualization using Unicode block characters.",
      imagePath: "screenshots/unicode_charts.png",
      command: "nim c -r examples/unicode_charts_example.nim"
    ),
    (
      title: "Unicode Handling Comparison",
      description: "Side-by-side comparison of basic vs. enhanced Unicode handling.",
      imagePath: "screenshots/unicode_comparison.png",
      command: "nim c -r examples/unicode_comparison.nim"
    )
  ]
  
  result = ""
  for example in examples:
    var card = exampleCardTemplate
    card = card.replace("$TITLE$", example.title)
    card = card.replace("$DESCRIPTION$", example.description)
    card = card.replace("$IMAGE_PATH$", example.imagePath)
    card = card.replace("$COMMAND$", example.command)
    result.add(card)

proc generateShowcase(outputPath: string) =
  # Create screenshots directory if it doesn't exist
  let screenshotsDir = joinPath(outputPath, "screenshots")
  if not dirExists(screenshotsDir):
    createDir(screenshotsDir)
  
  # Add placeholders for screenshots
  let placeholderContent = """
# Screenshot Placeholders

This directory should contain screenshots of the example applications.
You can capture screenshots of each example and place them here with the following names:

- enhanced_unicode.png
- complex_scripts.png
- typing_effect.png
- unicode_tables.png
- i18n_example.png
- unicode_text_editor.png
- unicode_charts.png
- unicode_comparison.png

The showcase will automatically include these images when they are available.
"""
  
  writeFile(joinPath(screenshotsDir, "README.md"), placeholderContent)
  
  # Generate the HTML content
  var html = htmlTemplate
  let exampleCards = createExampleCards()
  html = html.replace("$EXAMPLES$", exampleCards)
  html = html.replace("$DATE$", format(now(), "MMMM d, yyyy"))
  
  # Write the HTML file
  writeFile(joinPath(outputPath, "index.html"), html)
  
  # Create a CSS file with the same styles
  let cssContent = """
/* This is extracted from the HTML file for reference */
/* You can modify this file directly for custom styling */

:root {
  --primary-color: #6a5acd;
  --secondary-color: #4b3d93;
  --text-color: #333;
  --background-color: #f9f9f9;
  --card-bg: #fff;
  --code-bg: #f0f0f0;
  --header-bg: #6a5acd;
  --header-text: #fff;
}

@media (prefers-color-scheme: dark) {
  :root {
    --primary-color: #8b7ddd;
    --secondary-color: #6a5acd;
    --text-color: #e0e0e0;
    --background-color: #1a1a1a;
    --card-bg: #2d2d2d;
    --code-bg: #333;
    --header-bg: #4b3d93;
    --header-text: #fff;
  }
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
  line-height: 1.6;
  color: var(--text-color);
  background-color: var(--background-color);
  margin: 0;
  padding: 0;
}

/* ... remaining styles from the HTML ... */
"""
  
  writeFile(joinPath(outputPath, "styles.css"), cssContent)
  
  # Create a script to capture screenshots
  let scriptContent = """#!/bin/bash
# Screenshot capture script for libterminal examples
# 
# This script will run each example and capture a screenshot
# Requirements: 
# - asciinema and svg-term-cli for terminal captures
# - OR use a manual screenshot tool while examples are running

examples=(
  "enhanced_unicode_example"
  "complex_scripts_example"
  "typing_effect_example"
  "unicode_tables_example"
  "i18n_example"
  "unicode_text_editor"
  "unicode_charts_example"
  "unicode_comparison"
)

echo "This script will help you capture screenshots of each example."
echo "You should manually capture screenshots as each example runs."
echo

mkdir -p screenshots

for example in "${examples[@]}"; do
  echo "Running: $example"
  echo "Please capture a screenshot while this example is running."
  echo "Press Enter to start the example..."
  read
  
  # Run the example
  nim c -r examples/$example.nim
  
  echo "Did you capture the screenshot? (y/n)"
  read response
  if [ "$response" = "y" ]; then
    echo "Please save the screenshot as screenshots/$example.png"
  else
    echo "You can run this script again later to capture missing screenshots."
  fi
  echo
done

echo "Screenshot capture complete!"
echo "Place all screenshots in the screenshots/ directory with the correct names."
echo "Then open index.html to view the complete showcase."
"""
  
  writeFile(joinPath(outputPath, "capture_screenshots.sh"), scriptContent)
  os.setFilePermissions(joinPath(outputPath, "capture_screenshots.sh"), {fpUserExec, fpUserWrite, fpUserRead})
  
  # Create a README file
  let readmeContent = """# libterminal Unicode Showcase

This directory contains a web-based showcase of libterminal's Unicode capabilities.

## Getting Started

1. Open `index.html` in your browser to view the showcase.
2. Run `./capture_screenshots.sh` to capture screenshots of examples.
3. Place the screenshots in the `screenshots/` directory with the correct names.
4. Refresh `index.html` to see the complete showcase with screenshots.

## Customization

You can customize the showcase by:

1. Editing `index.html` to modify content
2. Editing `styles.css` to change the appearance
3. Adding your own screenshots to the `screenshots/` directory

## Sharing

This is a static HTML showcase, so you can:

1. Host it on any web server
2. Share it via email by zipping this directory
3. Include it in your project documentation

## Screenshots Required

The following screenshots are needed:

- enhanced_unicode.png
- complex_scripts.png
- typing_effect.png
- unicode_tables.png
- i18n_example.png
- unicode_text_editor.png
- unicode_charts.png
- unicode_comparison.png
"""
  
  writeFile(joinPath(outputPath, "README.md"), readmeContent)
  
  echo "Web showcase generated in: ", outputPath
  echo "To complete the showcase:"
  echo "1. Run the capture_screenshots.sh script to capture screenshots"
  echo "2. Open index.html in a browser to view the showcase"

proc main() =
  let outputDir = 
    if paramCount() > 0:
      paramStr(1)
    else:
      "unicode_showcase"
  
  # Create the output directory if it doesn't exist
  if not dirExists(outputDir):
    createDir(outputDir)
  
  generateShowcase(outputDir)

when isMainModule:
  main()