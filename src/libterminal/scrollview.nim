import widgets, output, input, unicode, private/common

type
  ScrollBarVisibility* = enum
    ScrollBarAuto,       # Show scrollbar only when needed
    ScrollBarAlways,     # Always show scrollbar
    ScrollBarNever       # Never show scrollbar
  
  ScrollDirection* = enum
    ScrollHorizontal,    # Horizontal scrolling
    ScrollVertical,      # Vertical scrolling
    ScrollBoth           # Both horizontal and vertical scrolling
  
  ScrollViewState* = ref object of WidgetState
    contentWidget*: Widget           # The widget being scrolled
    viewportX*: int                  # Horizontal scroll position
    viewportY*: int                  # Vertical scroll position
    contentWidth*: int               # Total content width
    contentHeight*: int              # Total content height
    horizontalScrollBarVisible*: bool
    verticalScrollBarVisible*: bool
    horizontalScrollBarPolicy*: ScrollBarVisibility
    verticalScrollBarPolicy*: ScrollBarVisibility
    allowedScrollDirections*: ScrollDirection
    scrollStep*: int                 # Scroll amount per key/wheel
    smoothScrolling*: bool           # Use smooth scrolling (not just multiples of scrollStep)
    onScroll*: proc(viewportX, viewportY: int) {.closure.}

proc newScrollViewState*(): ScrollViewState =
  result = ScrollViewState()
  result.contentWidget = nil
  result.viewportX = 0
  result.viewportY = 0
  result.contentWidth = 0
  result.contentHeight = 0
  result.horizontalScrollBarVisible = false
  result.verticalScrollBarVisible = false
  result.horizontalScrollBarPolicy = ScrollBarAuto
  result.verticalScrollBarPolicy = ScrollBarAuto
  result.allowedScrollDirections = ScrollBoth
  result.scrollStep = 1
  result.smoothScrolling = true
  result.onScroll = nil

proc newScrollView*(id: string): Widget =
  result = newWidget(id, 0, 0, 40, 20)
  result.state = newScrollViewState()
  
  # Default style
  result.style.fg = ColorDefault
  result.style.bg = ColorDefault
  
  # Scrollable views should be visible and focusable
  result.flags.incl(WidgetVisible)
  result.flags.incl(WidgetFocusable)

proc getScrollViewState*(widget: Widget): ScrollViewState =
  return ScrollViewState(widget.state)

proc setContentWidget*(scrollView: Widget, contentWidget: Widget) =
  let state = scrollView.getScrollViewState()
  
  # Remove the old content widget if it exists
  if state.contentWidget != nil:
    discard scrollView.removeChild(state.contentWidget)
  
  # Set the new content widget
  state.contentWidget = contentWidget
  
  # Add the widget as a child
  scrollView.addChild(contentWidget)
  
  # Reset scroll position
  state.viewportX = 0
  state.viewportY = 0
  
  scrollView.markDirty()

proc setScrollBarPolicy*(scrollView: Widget, 
                        horizontalPolicy: ScrollBarVisibility = ScrollBarAuto,
                        verticalPolicy: ScrollBarVisibility = ScrollBarAuto) =
  let state = scrollView.getScrollViewState()
  state.horizontalScrollBarPolicy = horizontalPolicy
  state.verticalScrollBarPolicy = verticalPolicy
  scrollView.markDirty()

proc setAllowedScrollDirections*(scrollView: Widget, directions: ScrollDirection) =
  let state = scrollView.getScrollViewState()
  state.allowedScrollDirections = directions
  scrollView.markDirty()

proc setScrollStep*(scrollView: Widget, step: int) =
  let state = scrollView.getScrollViewState()
  state.scrollStep = max(1, step)  # Ensure step is at least 1
  scrollView.markDirty()

proc setSmoothScrolling*(scrollView: Widget, smooth: bool) =
  let state = scrollView.getScrollViewState()
  state.smoothScrolling = smooth
  scrollView.markDirty()

proc setOnScroll*(scrollView: Widget, callback: proc(viewportX, viewportY: int) {.closure.}) =
  let state = scrollView.getScrollViewState()
  state.onScroll = callback

proc scrollTo*(scrollView: Widget, x, y: int) =
  let state = scrollView.getScrollViewState()
  
  # Skip if we don't have a content widget
  if state.contentWidget == nil:
    return
  
  # Calculate max allowed scroll positions
  let viewportWidth = scrollView.rect.width - (if state.verticalScrollBarVisible: 1 else: 0)
  let viewportHeight = scrollView.rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
  
  let maxScrollX = max(0, state.contentWidth - viewportWidth)
  let maxScrollY = max(0, state.contentHeight - viewportHeight)
  
  # Apply allowed scroll directions
  var newX = state.viewportX
  var newY = state.viewportY
  
  if state.allowedScrollDirections in [ScrollHorizontal, ScrollBoth]:
    newX = max(0, min(x, maxScrollX))
  
  if state.allowedScrollDirections in [ScrollVertical, ScrollBoth]:
    newY = max(0, min(y, maxScrollY))
  
  # Update if changed
  if newX != state.viewportX or newY != state.viewportY:
    state.viewportX = newX
    state.viewportY = newY
    
    # Call the scroll callback if it exists
    if state.onScroll != nil:
      state.onScroll(newX, newY)
    
    scrollView.markDirty()

proc scrollBy*(scrollView: Widget, deltaX, deltaY: int) =
  let state = scrollView.getScrollViewState()
  scrollView.scrollTo(state.viewportX + deltaX, state.viewportY + deltaY)

proc scrollToTop*(scrollView: Widget) =
  scrollView.scrollTo(scrollView.getScrollViewState().viewportX, 0)

proc scrollToBottom*(scrollView: Widget) =
  let state = scrollView.getScrollViewState()
  let viewportHeight = scrollView.rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
  let maxScrollY = max(0, state.contentHeight - viewportHeight)
  scrollView.scrollTo(state.viewportX, maxScrollY)

proc scrollToLeft*(scrollView: Widget) =
  scrollView.scrollTo(0, scrollView.getScrollViewState().viewportY)

proc scrollToRight*(scrollView: Widget) =
  let state = scrollView.getScrollViewState()
  let viewportWidth = scrollView.rect.width - (if state.verticalScrollBarVisible: 1 else: 0)
  let maxScrollX = max(0, state.contentWidth - viewportWidth)
  scrollView.scrollTo(maxScrollX, state.viewportY)

proc getContentSize(scrollView: Widget): tuple[width, height: int] =
  let state = scrollView.getScrollViewState()
  
  if state.contentWidget == nil:
    return (0, 0)
  
  # Get the content widget's size
  # This may be different depending on the type of widget
  var width = 0
  var height = 0
  
  # First try to get size from the rect
  width = state.contentWidget.rect.width
  height = state.contentWidget.rect.height
  
  # Store the content size in the state
  state.contentWidth = max(width, 1)
  state.contentHeight = max(height, 1)
  
  return (state.contentWidth, state.contentHeight)

proc updateScrollBarVisibility(scrollView: Widget) =
  let state = scrollView.getScrollViewState()
  
  # Get the content size
  let (contentWidth, contentHeight) = scrollView.getContentSize()
  
  # Get the viewport size (accounting for scrollbars)
  let viewportWidth = scrollView.rect.width - (if state.verticalScrollBarVisible: 1 else: 0)
  let viewportHeight = scrollView.rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
  
  # Determine horizontal scrollbar visibility
  case state.horizontalScrollBarPolicy
  of ScrollBarAlways:
    state.horizontalScrollBarVisible = true
  of ScrollBarNever:
    state.horizontalScrollBarVisible = false
  of ScrollBarAuto:
    state.horizontalScrollBarVisible = contentWidth > viewportWidth
  
  # Determine vertical scrollbar visibility
  case state.verticalScrollBarPolicy
  of ScrollBarAlways:
    state.verticalScrollBarVisible = true
  of ScrollBarNever:
    state.verticalScrollBarVisible = false
  of ScrollBarAuto:
    state.verticalScrollBarVisible = contentHeight > viewportHeight
  
  # Adjust for scroll directions
  if state.allowedScrollDirections == ScrollHorizontal:
    state.verticalScrollBarVisible = false
  elif state.allowedScrollDirections == ScrollVertical:
    state.horizontalScrollBarVisible = false

proc updateContentPosition(scrollView: Widget) =
  let state = scrollView.getScrollViewState()
  
  if state.contentWidget == nil:
    return
  
  # Position the content widget according to the scroll position
  state.contentWidget.rect.x = scrollView.rect.x - state.viewportX
  state.contentWidget.rect.y = scrollView.rect.y - state.viewportY

proc renderScrollBar(scrollView: Widget, isHorizontal: bool) =
  let state = scrollView.getScrollViewState()
  let rect = scrollView.rect
  
  if (isHorizontal and not state.horizontalScrollBarVisible) or
     (not isHorizontal and not state.verticalScrollBarVisible):
    return
  
  # Get the content and viewport dimensions
  let viewportWidth = rect.width - (if state.verticalScrollBarVisible: 1 else: 0)
  let viewportHeight = rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
  
  if isHorizontal:
    # Horizontal scrollbar
    let barLength = rect.width - (if state.verticalScrollBarVisible: 1 else: 0)
    if barLength <= 0:
      return
    
    let contentWidth = max(state.contentWidth, 1)
    let thumbSize = max(1, int((float(viewportWidth) / float(contentWidth)) * float(barLength)))
    let thumbPos = int((float(state.viewportX) / float(contentWidth)) * float(barLength))
    
    # Draw the scrollbar
    setCursor(rect.x, rect.y + rect.height - 1)
    
    var style = Style(fg: scrollView.style.fg, bg: scrollView.style.bg)
    setStyle(style)
    
    for i in 0..<barLength:
      if i >= thumbPos and i < thumbPos + thumbSize:
        stdout.write("▀")
      else:
        stdout.write("─")
  else:
    # Vertical scrollbar
    let barLength = rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
    if barLength <= 0:
      return
    
    let contentHeight = max(state.contentHeight, 1)
    let thumbSize = max(1, int((float(viewportHeight) / float(contentHeight)) * float(barLength)))
    let thumbPos = int((float(state.viewportY) / float(contentHeight)) * float(barLength))
    
    # Draw the scrollbar
    var style = Style(fg: scrollView.style.fg, bg: scrollView.style.bg)
    setStyle(style)
    
    for i in 0..<barLength:
      setCursor(rect.x + rect.width - 1, rect.y + i)
      if i >= thumbPos and i < thumbPos + thumbSize:
        stdout.write("█")
      else:
        stdout.write("│")
  
  # Draw the corner if both scrollbars are visible
  if state.horizontalScrollBarVisible and state.verticalScrollBarVisible:
    setCursor(rect.x + rect.width - 1, rect.y + rect.height - 1)
    stdout.write("┘")

proc renderScrollView*(widget: Widget) =
  let state = widget.getScrollViewState()
  let rect = widget.rect
  
  # Skip rendering if the rect is invalid
  if rect.width <= 0 or rect.height <= 0:
    return
  
  # Update scrollbar visibility
  updateScrollBarVisibility(widget)
  
  # If there's no content, just clear the area
  if state.contentWidget == nil:
    var style = Style(fg: widget.style.fg, bg: widget.style.bg)
    setStyle(style)
    
    for y in 0..<rect.height:
      setCursor(rect.x, rect.y + y)
      for x in 0..<rect.width:
        stdout.write(" ")
    
    return
  
  # Update the content position
  updateContentPosition(widget)
  
  # Clear the viewport with the background color
  var style = Style(fg: widget.style.fg, bg: widget.style.bg)
  setStyle(style)
  
  let viewportWidth = rect.width - (if state.verticalScrollBarVisible: 1 else: 0)
  let viewportHeight = rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
  
  for y in 0..<viewportHeight:
    setCursor(rect.x, rect.y + y)
    for x in 0..<viewportWidth:
      stdout.write(" ")
  
  # Draw the scrollbars
  if state.horizontalScrollBarVisible:
    renderScrollBar(widget, true)
  
  if state.verticalScrollBarVisible:
    renderScrollBar(widget, false)
  
  # The content widget will be rendered by the widget manager

proc handleScrollViewKeyEvent*(widget: Widget, event: KeyEvent): bool =
  let state = widget.getScrollViewState()
  
  # If we have a content widget, let it handle the key first
  if state.contentWidget != nil:
    # TODO: Pass the key to the content widget
    discard
  
  # Handle scrolling keys
  case event.key
  of KeyUp:
    if state.allowedScrollDirections in [ScrollVertical, ScrollBoth]:
      widget.scrollBy(0, -state.scrollStep)
      return true
  of KeyDown:
    if state.allowedScrollDirections in [ScrollVertical, ScrollBoth]:
      widget.scrollBy(0, state.scrollStep)
      return true
  of KeyLeft:
    if state.allowedScrollDirections in [ScrollHorizontal, ScrollBoth]:
      widget.scrollBy(-state.scrollStep, 0)
      return true
  of KeyRight:
    if state.allowedScrollDirections in [ScrollHorizontal, ScrollBoth]:
      widget.scrollBy(state.scrollStep, 0)
      return true
  of KeyHome:
    if state.allowedScrollDirections == ScrollHorizontal:
      widget.scrollToLeft()
    elif state.allowedScrollDirections == ScrollVertical:
      widget.scrollToTop()
    else:
      widget.scrollTo(0, 0)
    return true
  of KeyEnd:
    if state.allowedScrollDirections == ScrollHorizontal:
      widget.scrollToRight()
    elif state.allowedScrollDirections == ScrollVertical:
      widget.scrollToBottom()
    else:
      let viewportWidth = widget.rect.width - (if state.verticalScrollBarVisible: 1 else: 0)
      let viewportHeight = widget.rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
      let maxScrollX = max(0, state.contentWidth - viewportWidth)
      let maxScrollY = max(0, state.contentHeight - viewportHeight)
      widget.scrollTo(maxScrollX, maxScrollY)
    return true
  of KeyPageUp:
    if state.allowedScrollDirections in [ScrollVertical, ScrollBoth]:
      let viewportHeight = widget.rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
      widget.scrollBy(0, -max(1, viewportHeight - 1))
      return true
  of KeyPageDown:
    if state.allowedScrollDirections in [ScrollVertical, ScrollBoth]:
      let viewportHeight = widget.rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
      widget.scrollBy(0, max(1, viewportHeight - 1))
      return true
  else:
    discard
  
  return false

proc handleScrollViewMouseEvent*(widget: Widget, event: MouseEvent): bool =
  let state = widget.getScrollViewState()
  
  # Handle scroll wheel events
  if event.button == MouseWheelUp:
    if state.allowedScrollDirections in [ScrollVertical, ScrollBoth]:
      widget.scrollBy(0, -state.scrollStep)
      return true
  elif event.button == MouseWheelDown:
    if state.allowedScrollDirections in [ScrollVertical, ScrollBoth]:
      widget.scrollBy(0, state.scrollStep)
      return true
  
  # Handle clicks on scrollbars
  if event.action == MousePressed and event.button == MouseLeft:
    let rect = widget.rect
    
    # Check if the click is on the horizontal scrollbar
    if state.horizontalScrollBarVisible and event.y == rect.y + rect.height - 1 and
       event.x >= rect.x and event.x < rect.x + rect.width - (if state.verticalScrollBarVisible: 1 else: 0):
      # Calculate scroll position based on click position
      let barLength = rect.width - (if state.verticalScrollBarVisible: 1 else: 0)
      let clickPos = event.x - rect.x
      let contentWidth = max(state.contentWidth, 1)
      let viewportWidth = rect.width - (if state.verticalScrollBarVisible: 1 else: 0)
      
      let scrollPos = int((float(clickPos) / float(barLength)) * float(contentWidth - viewportWidth))
      widget.scrollTo(scrollPos, state.viewportY)
      return true
    
    # Check if the click is on the vertical scrollbar
    if state.verticalScrollBarVisible and event.x == rect.x + rect.width - 1 and
       event.y >= rect.y and event.y < rect.y + rect.height - (if state.horizontalScrollBarVisible: 1 else: 0):
      # Calculate scroll position based on click position
      let barLength = rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
      let clickPos = event.y - rect.y
      let contentHeight = max(state.contentHeight, 1)
      let viewportHeight = rect.height - (if state.horizontalScrollBarVisible: 1 else: 0)
      
      let scrollPos = int((float(clickPos) / float(barLength)) * float(contentHeight - viewportHeight))
      widget.scrollTo(state.viewportX, scrollPos)
      return true
  
  # If this is a click, mouse move, or release inside the viewport (not on scrollbars),
  # adjust the event position for the content widget and pass it along
  if state.contentWidget != nil and
     event.x >= widget.rect.x and event.x < widget.rect.x + widget.rect.width - (if state.verticalScrollBarVisible: 1 else: 0) and
     event.y >= widget.rect.y and event.y < widget.rect.y + widget.rect.height - (if state.horizontalScrollBarVisible: 1 else: 0):
    
    # Adjust event coordinates for scrolling
    # TODO: Pass the adjusted event to the content widget
    discard
  
  return false

# Register scrollview widget handlers
proc registerScrollViewWidget*() =
  # registerWidgetRenderer("scrollview", renderScrollView)
  # registerWidgetKeyHandler("scrollview", handleScrollViewKeyEvent)
  # registerWidgetMouseHandler("scrollview", handleScrollViewMouseEvent)
  discard

# Auto-register when module is imported
registerScrollViewWidget()