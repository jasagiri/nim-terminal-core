import src/libterminal/private/unicode_utils

let rtlText = "مرحبا"  # Arabic "Hello"
echo "RTL text: ", rtlText
echo "Text direction: ", getTextDirection(rtlText)
echo "logicalPosToVisual(rtlText, 0) = ", logicalPosToVisual(rtlText, 0)
echo "Expected: not equal to 0"

let mixedText = "Hello مرحبا World"
echo "\nMixed text: ", mixedText
echo "Text direction: ", getTextDirection(mixedText)
echo "logicalPosToVisual(mixedText, 6) = ", logicalPosToVisual(mixedText, 6)
echo "Expected: not equal to 6"
