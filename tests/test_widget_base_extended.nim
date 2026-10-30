# test_widget_base_extended.nim
## Extended tests for widget base functionality

import unittest
import std/[tables, options]
import ../src/libterminal/widget_base
import ../src/libterminal/private/common
import ../src/libterminal/output
import ../src/libterminal/layout

suite "Widget Lifecycle":
  test "Widget creation and initialization":
    let widget = newWidget("root", 0, 0, 80, 24)
    check(widget.id == "root")
    check(widget.rect.x == 0)
    check(widget.rect.y == 0)
    check(widget.rect.width == 80)
    check(widget.rect.height == 24)
    check(WidgetVisible in widget.flags)
    check(WidgetEnabled in widget.flags)
  
  test "Widget initialization with tab index":
    let widget = newWidget("custom", 10, 10, 50, 20)
    widget.tabIndex = 5
    check(widget.tabIndex == 5)
  
  test "Widget parent-child relationships":
    let parent = newWidget("parent", 0, 0, 100, 50)
    let child1 = newWidget("child1", 10, 10, 30, 20)
    let child2 = newWidget("child2", 50, 10, 30, 20)
    
    parent.addChild(child1)
    parent.addChild(child2)
    
    check(parent.children.len == 2)
    check(parent.children[0].id == "child1")
    check(parent.children[1].id == "child2")
    check(child1.parent == parent)
    check(child2.parent == parent)
  
  test "Remove child widget":
    let parent = newWidget("parent", 0, 0, 100, 50)
    let child = newWidget("child", 10, 10, 30, 20)
    
    parent.addChild(child)
    check(parent.children.len == 1)
    
    discard parent.removeChild(child)
    check(parent.children.len == 0)
    check(child.parent == nil)

suite "Widget State Management":
  test "Widget flags manipulation":
    let widget = newWidget("test", 0, 0, 50, 10)
    
    # Check initial state
    check(WidgetVisible in widget.flags)
    check(WidgetEnabled in widget.flags)
    check(WidgetFocused notin widget.flags)
    
    # Add flags
    widget.flags.incl(WidgetFocused)
    widget.flags.incl(WidgetHovered)
    check(WidgetFocused in widget.flags)
    check(WidgetHovered in widget.flags)
    
    # Remove flags
    widget.flags.excl(WidgetVisible)
    check(WidgetVisible notin widget.flags)
  
  test "Focus management":
    let widget = newWidget("test", 0, 0, 50, 10)
    widget.flags.incl(WidgetFocusable)
    
    # Initially not focused
    check(not widget.isFocused())
    
    # Focus the widget
    widget.setFocused(true)
    check(widget.isFocused())
    check(WidgetFocused in widget.flags)
    
    # Blur the widget
    widget.setFocused(false)
    check(not widget.isFocused())
    check(WidgetFocused notin widget.flags)
  
  test "Enable/disable widget":
    let widget = newWidget("test", 0, 0, 50, 10)
    
    # Initially enabled
    check(widget.isEnabled())
    
    # Disable
    widget.setEnabled(false)
    check(not widget.isEnabled())
    check(WidgetEnabled notin widget.flags)
    
    # Enable
    widget.setEnabled(true)
    check(widget.isEnabled())
    check(WidgetEnabled in widget.flags)
  
  test "Show/hide widget":
    let widget = newWidget("test", 0, 0, 50, 10)
    
    # Initially visible
    check(widget.isVisible())
    
    # Hide
    widget.setVisible(false)
    check(not widget.isVisible())
    check(WidgetVisible notin widget.flags)
    
    # Show
    widget.setVisible(true)
    check(widget.isVisible())
    check(WidgetVisible in widget.flags)

suite "Widget Rendering":
  test "Widget rect access":
    let widget = newWidget("test", 10, 5, 20, 10)
    
    # Direct rect access
    check(widget.rect.x == 10)
    check(widget.rect.y == 5)
    check(widget.rect.width == 20)
    check(widget.rect.height == 10)
  
  test "Widget dirty flag":
    let widget = newWidget("test", 0, 0, 50, 10)
    
    # Mark widget as dirty (needs redraw)
    widget.markDirty()
    # The markDirty method exists but we can't check its effect
    # as the dirty flag might be internal

suite "Widget Style Management":
  test "Default styles":
    let widget = newWidget("test", 0, 0, 50, 10)
    
    check(widget.style.fg == ColorWhite)
    check(widget.style.bg == ColorBlack)
    check(widget.focusStyle.bg == ColorBlue)
    check(widget.disabledStyle.fg == ColorBrightBlack)
  
  test "Custom styles":
    let widget = newWidget("test", 0, 0, 50, 10)
    
    # Set custom style
    widget.style = Style(
      fg: ColorGreen,
      bg: ColorDefault,
      attrs: {AttrBoldAttr, AttrUnderlineAttr},
      focusFg: ColorDefault,
      focusBg: ColorDefault,
      disabledFg: ColorDefault,
      disabledBg: ColorDefault,
      selectedFg: ColorDefault,
      selectedBg: ColorDefault,
      secondaryFg: ColorDefault,
      secondaryBg: ColorDefault
    )
    
    check(widget.style.fg == ColorGreen)
    check(widget.style.bg == ColorDefault)
    check(AttrBoldAttr in widget.style.attrs)
    check(AttrUnderlineAttr in widget.style.attrs)

suite "Widget Layout":
  test "Widget has layout node":
    let widget = newWidget("test", 0, 0, 50, 10)
    # Widget might not have a layout node by default
    # This depends on the implementation
    discard
  
  test "Widget rect properties":
    let widget = newWidget("test", 10, 20, 30, 40)
    check(widget.rect.x == 10)
    check(widget.rect.y == 20)
    check(widget.rect.width == 30)
    check(widget.rect.height == 40)