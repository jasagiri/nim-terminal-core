# test_layout.nim
## レイアウトシステムテスト

import unittest
import ../src/libterminal/layout
import ../src/libterminal/private/common
import ../src/libterminal/widget_base

suite "基本レイアウト":
  test "レイアウトノード作成":
    let node = newLayoutNode("test", LayoutHorizontal)
    check(node != nil)
    check(node.rect.x == 0)
    check(node.rect.y == 0)
    check(node.rect.width == 0)
    check(node.rect.height == 0)
    check(node.visible == true)
    check(node.margin.left == 0)
    check(node.margin.right == 0)
    check(node.margin.top == 0)
    check(node.margin.bottom == 0)
    check(node.children.len == 0)
  
  test "レイアウトの基本機能":
    # Basic layout creation test
    let node1 = newLayoutNode("node1", LayoutVertical)
    let node2 = newLayoutNode("node2", LayoutHorizontal)
    check(node1 != nil)
    check(node2 != nil)
    check(node1.kind == LayoutVertical)
    check(node2.kind == LayoutHorizontal)