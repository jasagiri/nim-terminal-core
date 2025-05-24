# Terminal Dashboard
# A comprehensive application demonstrating data visualization and monitoring

import std/random
import std/times
import std/strformat
import std/strutils
import std/math
import libterminal
import libterminal/shortcuts
import libterminal/databinding

type
  SystemMetrics = ref object
    cpuUsage*: float
    memoryUsage*: float
    diskUsage*: float
    networkIn*: float
    networkOut*: float
    uptime*: int
    processes*: int

  LogEntry = object
    timestamp*: string
    level*: string
    message*: string

proc generateRandomMetrics(): SystemMetrics =
  ## Generate random system metrics for demo
  result = SystemMetrics(
    cpuUsage: rand(100.0),
    memoryUsage: rand(100.0),
    diskUsage: 45.0 + rand(20.0),  # More stable disk usage
    networkIn: rand(1000.0),
    networkOut: rand(800.0),
    uptime: 3600 + rand(86400),  # 1-25 hours
    processes: 120 + rand(50)
  )

proc formatUptime(seconds: int): string =
  let hours = seconds div 3600
  let minutes = (seconds mod 3600) div 60
  return fmt"{hours}h {minutes}m"

proc formatNetworkSpeed(bytesPerSec: float): string =
  if bytesPerSec < 1024:
    return fmt"{bytesPerSec:.1f} B/s"
  elif bytesPerSec < 1024 * 1024:
    return fmt"{bytesPerSec / 1024:.1f} KB/s"
  else:
    return fmt"{bytesPerSec / (1024 * 1024):.1f} MB/s"

proc generateLogEntry(): LogEntry =
  let levels = ["INFO", "WARN", "ERROR", "DEBUG"]
  let messages = [
    "System started successfully",
    "Network connection established", 
    "Memory usage threshold reached",
    "Disk cleanup completed",
    "User authentication successful",
    "Configuration file loaded",
    "Service restart requested",
    "Backup process initiated"
  ]
  
  result = LogEntry(
    timestamp: now().format("HH:mm:ss"),
    level: levels[rand(levels.high)],
    message: messages[rand(messages.high)]
  )

proc main() =
  # Initialize terminal and random
  initTerminal()
  randomize()
  
  # Create buffer and widget manager
  var buffer = newBuffer(getTerminalWidth(), getTerminalHeight())
  var manager = newWidgetManager(buffer)
  
  # Create shortcut manager
  var shortcuts = newShortcutManager()
  
  # Create binding manager and data context
  var bindingManager = newBindingManager()
  var dataContext = newDataContext()
  
  # System metrics
  var metrics = generateRandomMetrics()
  var logEntries: seq[LogEntry] = @[]
  
  # Add properties to data context
  dataContext.addProperty(newFloatProperty("cpuUsage", metrics.cpuUsage))
  dataContext.addProperty(newFloatProperty("memoryUsage", metrics.memoryUsage))
  dataContext.addProperty(newFloatProperty("diskUsage", metrics.diskUsage))
  dataContext.addProperty(newStringProperty("uptime", formatUptime(metrics.uptime)))
  dataContext.addProperty(newIntProperty("processes", metrics.processes))
  dataContext.addProperty(newStringProperty("networkIn", formatNetworkSpeed(metrics.networkIn)))
  dataContext.addProperty(newStringProperty("networkOut", formatNetworkSpeed(metrics.networkOut)))
  
  bindingManager.addContext("system", dataContext)
  
  # Create main layout
  var mainLayout = newVerticalLayout("main")
  mainLayout.rect = Rect(x: 0, y: 0, width: getTerminalWidth(), height: getTerminalHeight())
  
  # Create title bar
  var titleBar = newLabel("titleBar", "System Dashboard - " & now().format("yyyy-MM-dd HH:mm:ss"))
  titleBar.setTextAlign(TextAlignCenter)
  titleBar.style.fg = ColorWhite
  titleBar.style.bg = ColorBlue
  
  # Create main content area
  var contentLayout = newHorizontalLayout("content")
  
  # Left panel - Metrics
  var metricsPanel = newVerticalLayout("metrics")
  
  # CPU Usage
  var cpuLabel = newLabel("cpuLabel", "CPU Usage")
  cpuLabel.style.fg = ColorCyan
  var cpuProgress = newProgressBar("cpuProgress")
  cpuProgress.setProgress(metrics.cpuUsage / 100.0)
  var cpuText = newLabel("cpuText", fmt"{metrics.cpuUsage:.1f}%")
  
  # Memory Usage  
  var memLabel = newLabel("memLabel", "Memory Usage")
  memLabel.style.fg = ColorGreen
  var memProgress = newProgressBar("memProgress")
  memProgress.setProgress(metrics.memoryUsage / 100.0)
  var memText = newLabel("memText", fmt"{metrics.memoryUsage:.1f}%")
  
  # Disk Usage
  var diskLabel = newLabel("diskLabel", "Disk Usage")
  diskLabel.style.fg = ColorYellow
  var diskProgress = newProgressBar("diskProgress")
  diskProgress.setProgress(metrics.diskUsage / 100.0)
  var diskText = newLabel("diskText", fmt"{metrics.diskUsage:.1f}%")
  
  # System Info
  var infoLabel = newLabel("infoLabel", "System Information")
  infoLabel.style.fg = ColorMagenta
  var uptimeLabel = newLabel("uptimeLabel", "Uptime: " & formatUptime(metrics.uptime))
  var processLabel = newLabel("processLabel", fmt"Processes: {metrics.processes}")
  var networkInLabel = newLabel("networkInLabel", "In: " & formatNetworkSpeed(metrics.networkIn))
  var networkOutLabel = newLabel("networkOutLabel", "Out: " & formatNetworkSpeed(metrics.networkOut))
  
  # Add to metrics panel
  metricsPanel.addWidget(cpuLabel, LayoutSizeFixed, 1)
  metricsPanel.addWidget(cpuProgress, LayoutSizeFixed, 1)
  metricsPanel.addWidget(cpuText, LayoutSizeFixed, 1)
  metricsPanel.addWidget(memLabel, LayoutSizeFixed, 1)
  metricsPanel.addWidget(memProgress, LayoutSizeFixed, 1)
  metricsPanel.addWidget(memText, LayoutSizeFixed, 1)
  metricsPanel.addWidget(diskLabel, LayoutSizeFixed, 1)
  metricsPanel.addWidget(diskProgress, LayoutSizeFixed, 1)
  metricsPanel.addWidget(diskText, LayoutSizeFixed, 1)
  metricsPanel.addWidget(infoLabel, LayoutSizeFixed, 1)
  metricsPanel.addWidget(uptimeLabel, LayoutSizeFixed, 1)
  metricsPanel.addWidget(processLabel, LayoutSizeFixed, 1)
  metricsPanel.addWidget(networkInLabel, LayoutSizeFixed, 1)
  metricsPanel.addWidget(networkOutLabel, LayoutSizeFixed, 1)
  
  # Center panel - Process List (using table)
  var processPanel = newVerticalLayout("processPanel")
  var processTitle = newLabel("processTitle", "Running Processes")
  processTitle.style.fg = ColorCyan
  
  var processTable = new TableView("processTable")
  processTable.addColumn("pid", "PID", 8, AlignRight, true)
  processTable.addColumn("name", "Process Name", 20, AlignLeft, true)
  processTable.addColumn("cpu", "CPU%", 8, AlignRight, true)
  processTable.addColumn("memory", "Memory%", 10, AlignRight, true)
  
  # Add sample process data
  let processNames = ["systemd", "kernel", "bash", "nvim", "firefox", "chrome", "nodejs", "python", "gcc", "make"]
  for i in 0..<15:
    let pid = 1000 + rand(8000)
    let name = processNames[rand(processNames.high)]
    let cpu = rand(25.0)
    let memory = rand(15.0)
    
    processTable.addRow(@[
      $pid,
      name,
      fmt"{cpu:.1f}",
      fmt"{memory:.1f}"
    ])
  
  processTable.selectCell(0, 0)
  
  processPanel.addWidget(processTitle, LayoutSizeFixed, 1)
  processPanel.addWidget(processTable, LayoutSizeFill, 0)
  
  # Right panel - Log viewer
  var logPanel = newVerticalLayout("logPanel")
  var logTitle = newLabel("logTitle", "System Log")
  logTitle.style.fg = ColorYellow
  
  var logList = newListBox("logList")
  
  # Generate initial log entries
  for i in 0..<10:
    let entry = generateLogEntry()
    logEntries.add(entry)
    let logLine = fmt"[{entry.timestamp}] {entry.level}: {entry.message}"
    logList.addItem(logLine)
  
  logPanel.addWidget(logTitle, LayoutSizeFixed, 1)
  logPanel.addWidget(logList, LayoutSizeFill, 0)
  
  # Status bar with controls
  var statusLayout = newHorizontalLayout("statusLayout")
  var refreshButton = newButton("refreshBtn", "Refresh (F5)")
  var pauseButton = newButton("pauseBtn", "Pause Updates")
  var clearLogButton = newButton("clearLogBtn", "Clear Log")
  var statusText = newLabel("statusText", "Auto-refresh: ON")
  
  statusLayout.addWidget(refreshButton, LayoutSizeAuto, 0)
  statusLayout.addWidget(pauseButton, LayoutSizeAuto, 0)
  statusLayout.addWidget(clearLogButton, LayoutSizeAuto, 0)
  statusLayout.addWidget(statusText, LayoutSizeFill, 0)
  
  # Set up data bindings
  
  # Bind CPU progress
  let cpuProgressProp = newFloatProperty("cpuProgressValue", metrics.cpuUsage / 100.0)
  cpuProgressProp.setAccessors(
    getter = proc(): PropertyValue = newPropertyValue(cpuProgress.getProgress()),
    setter = proc(value: PropertyValue) =
      cpuProgress.setProgress(value.asFloat() / 100.0)
    ,
    notifier = proc() = cpuProgress.markDirty()
  )
  
  discard bindingManager.createBinding(
    dataContext.getProperty("cpuUsage").get,
    cpuProgressProp,
    OneWayToTarget
  )
  
  # Bind CPU text
  let cpuTextProp = newStringProperty("cpuTextValue", fmt"{metrics.cpuUsage:.1f}%")
  cpuTextProp.setAccessors(
    getter = proc(): PropertyValue = newPropertyValue(cpuText.getText()),
    setter = proc(value: PropertyValue) =
      cpuText.setText(fmt"{value.asFloat():.1f}%")
    ,
    notifier = proc() = cpuText.markDirty()
  )
  
  discard bindingManager.createBinding(
    dataContext.getProperty("cpuUsage").get,
    cpuTextProp,
    OneWayToTarget
  )
  
  # Similar bindings for memory and disk (simplified here)
  # In a real application, you'd set up all the bindings
  
  # Update function
  var autoPaused = false
  var lastUpdate = epochTime()
  
  proc updateMetrics() =
    if autoPaused:
      return
    
    # Generate new metrics
    metrics = generateRandomMetrics()
    
    # Update data context
    dataContext.setFloatProperty("cpuUsage", metrics.cpuUsage)
    dataContext.setFloatProperty("memoryUsage", metrics.memoryUsage)
    dataContext.setFloatProperty("diskUsage", metrics.diskUsage)
    dataContext.setStringProperty("uptime", formatUptime(metrics.uptime))
    dataContext.setIntProperty("processes", metrics.processes)
    dataContext.setStringProperty("networkIn", formatNetworkSpeed(metrics.networkIn))
    dataContext.setStringProperty("networkOut", formatNetworkSpeed(metrics.networkOut))
    
    # Update progress bars and labels directly (since full binding is complex)
    memProgress.setProgress(metrics.memoryUsage / 100.0)
    memText.setText(fmt"{metrics.memoryUsage:.1f}%")
    diskProgress.setProgress(metrics.diskUsage / 100.0)
    diskText.setText(fmt"{metrics.diskUsage:.1f}%")
    
    uptimeLabel.setText("Uptime: " & formatUptime(metrics.uptime))
    processLabel.setText(fmt"Processes: {metrics.processes}")
    networkInLabel.setText("In: " & formatNetworkSpeed(metrics.networkIn))
    networkOutLabel.setText("Out: " & formatNetworkSpeed(metrics.networkOut))
    
    # Add new log entry occasionally
    if rand(100) < 30:  # 30% chance
      let entry = generateLogEntry()
      logEntries.add(entry)
      let logLine = fmt"[{entry.timestamp}] {entry.level}: {entry.message}"
      logList.addItem(logLine)
      
      # Keep only last 20 entries
      if logEntries.len > 20:
        logEntries.delete(0)
        logList.removeItem(0)
    
    # Update title with current time
    titleBar.setText("System Dashboard - " & now().format("yyyy-MM-dd HH:mm:ss"))
  
  # Set up button handlers
  refreshButton.setOnClick(proc() =
    updateMetrics()
  )
  
  pauseButton.setOnClick(proc() =
    autoPaused = not autoPaused
    if autoPaused:
      pauseButton.setText("Resume Updates")
      statusText.setText("Auto-refresh: PAUSED")
    else:
      pauseButton.setText("Pause Updates")
      statusText.setText("Auto-refresh: ON")
  )
  
  clearLogButton.setOnClick(proc() =
    logEntries.setLen(0)
    logList.clear()
    statusText.setText("Log cleared")
  )
  
  # Set up keyboard shortcuts
  shortcuts.registerShortcut(Key.F5, {}, "Refresh", proc() =
    updateMetrics()
  )
  
  shortcuts.registerShortcut(Key.Space, {}, "Pause/Resume", proc() =
    autoPaused = not autoPaused
    if autoPaused:
      pauseButton.setText("Resume Updates")
      statusText.setText("Auto-refresh: PAUSED")
    else:
      pauseButton.setText("Pause Updates")
      statusText.setText("Auto-refresh: ON")
  )
  
  shortcuts.registerShortcut(Key.C, {ModCtrl}, "Clear Log", proc() =
    logEntries.setLen(0)
    logList.clear()
    statusText.setText("Log cleared")
  )
  
  var shouldQuit = false
  shortcuts.registerShortcut(Key.Q, {ModCtrl}, "Quit", proc() =
    shouldQuit = true
  )
  
  shortcuts.registerShortcut(Key.F1, {}, "Show Help", proc() =
    let helpDialog = newDialog("helpDialog", "Dashboard Help")
    helpDialog.setContent("""System Dashboard

This dashboard shows real-time system information including:
- CPU, Memory, and Disk usage with progress bars
- System uptime and process count  
- Network throughput statistics
- Process list with resource usage
- System log entries

Keyboard Shortcuts:
- F5: Refresh data
- Space: Pause/Resume auto-updates
- Ctrl+C: Clear log
- Ctrl+Q: Quit
- F1: Show this help

The data shown is simulated for demonstration purposes.""")
    
    helpDialog.addButton("Close", proc() =
      discard manager.removeWidget(helpDialog)
    )
    
    manager.addWidget(helpDialog)
  )
  
  # Install shortcut handler
  shortcuts.installShortcutHandler(manager)
  
  # Arrange layout
  contentLayout.addWidget(metricsPanel, LayoutSizePercent, 30)
  contentLayout.addWidget(processPanel, LayoutSizePercent, 40)
  contentLayout.addWidget(logPanel, LayoutSizePercent, 30)
  
  mainLayout.addWidget(titleBar, LayoutSizeFixed, 1)
  mainLayout.addWidget(contentLayout, LayoutSizeFill, 0)
  mainLayout.addWidget(statusLayout, LayoutSizeFixed, 3)
  
  # Set initial focus
  manager.setFocus(processTable)
  
  # Set up layout
  manager.setRootLayout(mainLayout)
  
  # Main event loop
  var running = true
  while running and not shouldQuit:
    # Clear the screen
    clearScreen()
    
    # Auto-update every 2 seconds
    let currentTime = epochTime()
    if currentTime - lastUpdate > 2.0:
      updateMetrics()
      lastUpdate = currentTime
    
    # Layout and render widgets
    manager.layoutWidgets()
    manager.render()
    
    # Handle input
    let event = readEvent(100)  # 100ms timeout for responsive updates
    case event.kind
    of EvKey:
      if event.key == Key.Escape:
        running = false
      else:
        discard manager.handleEvent(event)
    of EvMouse:
      discard manager.handleEvent(event)
    of EvResize:
      mainLayout.rect.width = event.resize.width
      mainLayout.rect.height = event.resize.height
      buffer.resize(event.resize.width, event.resize.height)
    else:
      discard
  
  # Cleanup
  cleanupTerminal()

when isMainModule:
  main()