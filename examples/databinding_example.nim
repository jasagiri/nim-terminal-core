# Data Binding Example
# Demonstrates the use of the data binding system

import std/strformat
import std/strutils
import libterminal
import libterminal/databinding

type
  PersonData = ref object
    name*: string
    age*: int
    email*: string
    enabled*: bool
    progress*: float

proc main() =
  # Initialize terminal
  initTerminal()
  
  # Create buffer and widget manager
  var buffer = newBuffer(getTerminalWidth(), getTerminalHeight())
  var manager = newWidgetManager(buffer)
  
  # Create binding manager
  var bindingManager = newBindingManager()
  
  # Create a data context with person properties
  var dataContext = newDataContext()
  
  # Add properties to the data context
  dataContext.addProperty(newStringProperty("name", "John Doe"))
  dataContext.addProperty(newIntProperty("age", 25))
  dataContext.addProperty(newStringProperty("email", "john@example.com"))
  dataContext.addProperty(newBoolProperty("enabled", true))
  dataContext.addProperty(newFloatProperty("progress", 0.7))
  
  # Register context with binding manager
  bindingManager.addContext("person", dataContext)
  
  # Create a vertical layout for the app
  var mainLayout = newVerticalLayout("main")
  mainLayout.rect = Rect(x: 0, y: 0, width: getTerminalWidth(), height: getTerminalHeight())
  
  # Create title
  var titleLabel = newLabel("title", "Data Binding Example")
  titleLabel.setTextAlign(TextAlignCenter)
  titleLabel.style.fg = ColorYellow
  
  # Create form widgets bound to data
  var nameLabel = newLabel("nameLabel", "Name: John Doe")
  var ageLabel = newLabel("ageLabel", "Age: 25")
  var emailLabel = newLabel("emailLabel", "Email: john@example.com")
  var statusLabel = newLabel("statusLabel", "Status: Enabled")
  var progressLabel = newLabel("progressLabel", "Progress: 70%")
  
  # Create a progress bar
  var progressBar = newProgressBar("progressBar")
  progressBar.setProgress(0.7)
  
  # Create buttons to modify data
  var increaseAgeButton = newButton("increaseAge", "Increase Age")
  var toggleEnabledButton = newButton("toggleEnabled", "Toggle Enabled")
  var increaseProgressButton = newButton("increaseProgress", "Increase Progress")
  var changeNameButton = newButton("changeName", "Change Name")
  
  # Set up data bindings
  
  # Bind name label to name property
  nameLabel.initProperties()
  discard bindingManager.createPropertyPathBinding("person", "name", "widget", "text", OneWayToTarget)
  
  # Create custom converter for age label
  let ageConverter = proc(value: PropertyValue): PropertyValue =
    return newPropertyValue("Age: " & $value.asInt())
  
  # Create properties for the label widgets
  let ageProp = newStringProperty("ageDisplay", "Age: 25")
  ageProp.setAccessors(
    getter = proc(): PropertyValue = newPropertyValue(ageLabel.getText()),
    setter = proc(value: PropertyValue) =
      ageLabel.setText(value.asString())
    ,
    notifier = proc() = ageLabel.markDirty()
  )
  
  # Bind age property with converter
  discard bindingManager.createBinding(
    dataContext.getProperty("age").get,
    ageProp,
    OneWayToTarget,
    ageConverter
  )
  
  # Create email property with converter
  let emailConverter = proc(value: PropertyValue): PropertyValue =
    return newPropertyValue("Email: " & value.asString())
  
  let emailProp = newStringProperty("emailDisplay", "Email: john@example.com")
  emailProp.setAccessors(
    getter = proc(): PropertyValue = newPropertyValue(emailLabel.getText()),
    setter = proc(value: PropertyValue) =
      emailLabel.setText(value.asString())
    ,
    notifier = proc() = emailLabel.markDirty()
  )
  
  discard bindingManager.createBinding(
    dataContext.getProperty("email").get,
    emailProp,
    OneWayToTarget,
    emailConverter
  )
  
  # Create status property with converter
  let statusConverter = proc(value: PropertyValue): PropertyValue =
    let status = if value.asBool(): "Enabled" else: "Disabled"
    return newPropertyValue("Status: " & status)
  
  let statusProp = newStringProperty("statusDisplay", "Status: Enabled")
  statusProp.setAccessors(
    getter = proc(): PropertyValue = newPropertyValue(statusLabel.getText()),
    setter = proc(value: PropertyValue) =
      statusLabel.setText(value.asString())
    ,
    notifier = proc() = statusLabel.markDirty()
  )
  
  discard bindingManager.createBinding(
    dataContext.getProperty("enabled").get,
    statusProp,
    OneWayToTarget,
    statusConverter
  )
  
  # Create progress property with converters
  let progressConverter = proc(value: PropertyValue): PropertyValue =
    let percent = int(value.asFloat() * 100)
    return newPropertyValue("Progress: " & $percent & "%")
  
  let progressProp = newStringProperty("progressDisplay", "Progress: 70%")
  progressProp.setAccessors(
    getter = proc(): PropertyValue = newPropertyValue(progressLabel.getText()),
    setter = proc(value: PropertyValue) =
      progressLabel.setText(value.asString())
    ,
    notifier = proc() = progressLabel.markDirty()
  )
  
  discard bindingManager.createBinding(
    dataContext.getProperty("progress").get,
    progressProp,
    OneWayToTarget,
    progressConverter
  )
  
  # Bind progress bar directly
  let progressBarProp = newFloatProperty("progressValue", 0.7)
  progressBarProp.setAccessors(
    getter = proc(): PropertyValue = newPropertyValue(progressBar.getProgress()),
    setter = proc(value: PropertyValue) =
      progressBar.setProgress(value.asFloat())
    ,
    notifier = proc() = progressBar.markDirty()
  )
  
  discard bindingManager.createBinding(
    dataContext.getProperty("progress").get,
    progressBarProp,
    OneWayToTarget
  )
  
  # Set up button click handlers to modify data
  increaseAgeButton.setOnClick(proc() =
    let ageOpt = dataContext.getProperty("age")
    if ageOpt.isSome:
      let currentAge = ageOpt.get.getIntValue()
      ageOpt.get.setValue(currentAge + 1)
  )
  
  toggleEnabledButton.setOnClick(proc() =
    let enabledOpt = dataContext.getProperty("enabled")
    if enabledOpt.isSome:
      let currentEnabled = enabledOpt.get.getBoolValue()
      enabledOpt.get.setValue(not currentEnabled)
  )
  
  increaseProgressButton.setOnClick(proc() =
    let progressOpt = dataContext.getProperty("progress")
    if progressOpt.isSome:
      let currentProgress = progressOpt.get.getFloatValue()
      let newProgress = min(1.0, currentProgress + 0.1)
      progressOpt.get.setValue(newProgress)
  )
  
  var nameCounter = 0
  changeNameButton.setOnClick(proc() =
    let nameOpt = dataContext.getProperty("name")
    if nameOpt.isSome:
      inc nameCounter
      nameOpt.get.setValue("Person " & $nameCounter)
  )
  
  # Create layout structure
  
  # Data display section
  var dataSection = newVerticalLayout("dataSection")
  dataSection.addWidget(nameLabel, LayoutSizeFixed, 1)
  dataSection.addWidget(ageLabel, LayoutSizeFixed, 1)
  dataSection.addWidget(emailLabel, LayoutSizeFixed, 1)
  dataSection.addWidget(statusLabel, LayoutSizeFixed, 1)
  dataSection.addWidget(progressLabel, LayoutSizeFixed, 1)
  dataSection.addWidget(progressBar, LayoutSizeFixed, 1)
  
  # Buttons section
  var buttonsSection = newVerticalLayout("buttonsSection")
  buttonsSection.addWidget(increaseAgeButton, LayoutSizeFixed, 3)
  buttonsSection.addWidget(toggleEnabledButton, LayoutSizeFixed, 3)
  buttonsSection.addWidget(increaseProgressButton, LayoutSizeFixed, 3)
  buttonsSection.addWidget(changeNameButton, LayoutSizeFixed, 3)
  
  # Main horizontal layout
  var contentLayout = newHorizontalLayout("content")
  contentLayout.addWidget(dataSection, LayoutSizePercent, 60)
  contentLayout.addWidget(buttonsSection, LayoutSizePercent, 40)
  
  # Footer
  var footerLabel = newLabel("footer", "Click buttons to see data binding in action. Press ESC to exit.")
  footerLabel.setTextAlign(TextAlignCenter)
  footerLabel.style.fg = ColorBrightBlack
  
  # Add everything to main layout
  mainLayout.addWidget(titleLabel, LayoutSizeFixed, 1)
  mainLayout.addWidget(contentLayout, LayoutSizeFill, 0)
  mainLayout.addWidget(footerLabel, LayoutSizeFixed, 1)
  
  # Set up layout
  manager.setRootLayout(mainLayout)
  
  # Main event loop
  var running = true
  while running:
    # Clear the screen
    clearScreen()
    
    # Layout and render widgets
    manager.layoutWidgets()
    manager.render()
    
    # Handle input
    let event = readEvent(100)
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