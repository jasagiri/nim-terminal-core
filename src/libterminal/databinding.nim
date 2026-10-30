## databinding.nim
## Data binding system for libterminal widgets
##
## This module implements a data binding system that allows widgets to
## connect to data sources and automatically update when the data changes.

import std/tables
import std/hashes
import std/options
import std/strutils
# import std/macros  # Reserved for future use
import widgets

type
  BindingDirection* = enum
    ## Direction of data flow in binding
    OneWayToTarget,   ## Source -> Target only
    OneWayToSource,   ## Target -> Source only
    TwoWay            ## Bidirectional binding

  PropertyKind* = enum
    ## Type of property for binding
    StringProperty,
    IntProperty,
    FloatProperty,
    BoolProperty,
    CustomProperty

  PropertyValue* = object
    ## Value container for properties
    case kind*: PropertyKind
    of StringProperty:
      strValue*: string
    of IntProperty:
      intValue*: int
    of FloatProperty:
      floatValue*: float
    of BoolProperty:
      boolValue*: bool
    of CustomProperty:
      customValue*: pointer

  PropertyAccessor* = object
    ## Accessor for getting and setting properties
    getter*: proc(): PropertyValue {.closure.}
    setter*: proc(value: PropertyValue) {.closure.}
    notifier*: proc() {.closure.}

  BindableProperty* = ref object
    ## A property that can be bound to other properties
    name*: string
    value*: PropertyValue
    accessors*: PropertyAccessor
    bindings*: seq[Binding]
    isUpdating: bool  # Internal flag to prevent recursive updates

  Binding* = ref object
    ## Represents a binding between two properties
    source*: BindableProperty
    target*: BindableProperty
    direction*: BindingDirection
    active*: bool
    valueConverter*: proc(value: PropertyValue): PropertyValue {.closure.}

  DataContext* = ref object
    ## Container for data used in bindings
    properties*: Table[string, BindableProperty]

  BindingManager* = ref object
    ## Manages all bindings in the application
    bindings*: seq[Binding]
    contexts*: Table[string, DataContext]

#-----------------------------------------------------------------
# Property Value Helpers
#-----------------------------------------------------------------

proc newPropertyValue*(value: string): PropertyValue =
  ## Create a new string property value
  result = PropertyValue(kind: StringProperty, strValue: value)

proc newPropertyValue*(value: int): PropertyValue =
  ## Create a new int property value
  result = PropertyValue(kind: IntProperty, intValue: value)

proc newPropertyValue*(value: float): PropertyValue =
  ## Create a new float property value
  result = PropertyValue(kind: FloatProperty, floatValue: value)

proc newPropertyValue*(value: bool): PropertyValue =
  ## Create a new boolean property value
  result = PropertyValue(kind: BoolProperty, boolValue: value)

proc newCustomPropertyValue*(value: pointer): PropertyValue =
  ## Create a new custom property value
  result = PropertyValue(kind: CustomProperty, customValue: value)

proc `$`*(value: PropertyValue): string =
  ## Convert property value to string
  case value.kind
  of StringProperty:
    return value.strValue
  of IntProperty:
    return $value.intValue
  of FloatProperty:
    return $value.floatValue
  of BoolProperty:
    return $value.boolValue
  of CustomProperty:
    return "(custom)"

proc asString*(value: PropertyValue): string =
  ## Get property value as string
  case value.kind
  of StringProperty:
    return value.strValue
  of IntProperty:
    return $value.intValue
  of FloatProperty:
    return $value.floatValue
  of BoolProperty:
    return $value.boolValue
  of CustomProperty:
    return "(custom)"

proc asInt*(value: PropertyValue, default: int = 0): int =
  ## Get property value as int
  case value.kind
  of IntProperty:
    return value.intValue
  of StringProperty:
    try:
      return parseInt(value.strValue)
    except:
      return default
  of FloatProperty:
    return int(value.floatValue)
  of BoolProperty:
    return if value.boolValue: 1 else: 0
  of CustomProperty:
    return default

proc asFloat*(value: PropertyValue, default: float = 0.0): float =
  ## Get property value as float
  case value.kind
  of FloatProperty:
    return value.floatValue
  of IntProperty:
    return float(value.intValue)
  of StringProperty:
    try:
      return parseFloat(value.strValue)
    except:
      return default
  of BoolProperty:
    return if value.boolValue: 1.0 else: 0.0
  of CustomProperty:
    return default

proc asBool*(value: PropertyValue, default: bool = false): bool =
  ## Get property value as bool
  case value.kind
  of BoolProperty:
    return value.boolValue
  of IntProperty:
    return value.intValue != 0
  of FloatProperty:
    return value.floatValue != 0.0
  of StringProperty:
    if value.strValue.toLower() in ["false", "no", "0", "off", ""]:
      return false
    else:
      return true  # Any non-empty string is true
  of CustomProperty:
    return default

#-----------------------------------------------------------------
# Bindable Property
#-----------------------------------------------------------------

proc notifyValueChanged*(property: BindableProperty) =
  ## Notify that a property value has changed
  
  # Prevent recursive updates
  if property.isUpdating:
    return
  
  property.isUpdating = true
  defer: property.isUpdating = false
  
  # Call the property's notifier if it exists
  if property.accessors.notifier != nil:
    property.accessors.notifier()
  
  # Update bindings
  for binding in property.bindings:
    if binding.active:
      case binding.direction
      of OneWayToTarget:
        if binding.source == property:
          var value = property.value
          # Apply converter if present
          if binding.valueConverter != nil:
            value = binding.valueConverter(value)
          
          if binding.target.accessors.setter != nil:
            binding.target.accessors.setter(value)
          else:
            binding.target.value = value
            binding.target.notifyValueChanged()
      
      of OneWayToSource:
        if binding.target == property:
          var value = property.value
          # Apply converter in reverse if needed
          # (We don't have a reverse converter right now, just use the value directly)
          
          if binding.source.accessors.setter != nil:
            binding.source.accessors.setter(value)
          else:
            binding.source.value = value
            binding.source.notifyValueChanged()
      
      of TwoWay:
        if binding.source == property:
          var value = property.value
          # Apply converter if present
          if binding.valueConverter != nil:
            value = binding.valueConverter(value)
          
          if binding.target.accessors.setter != nil:
            binding.target.accessors.setter(value)
          else:
            binding.target.value = value
            binding.target.notifyValueChanged()
        elif binding.target == property:
          var value = property.value
          # Apply converter in reverse if needed
          # (We don't have a reverse converter right now, just use the value directly)
          
          if binding.source.accessors.setter != nil:
            binding.source.accessors.setter(value)
          else:
            binding.source.value = value
            binding.source.notifyValueChanged()

proc getValue*(property: BindableProperty): PropertyValue =
  ## Get the value of a property
  if property.accessors.getter != nil:
    return property.accessors.getter()
  return property.value

proc setValue*(property: BindableProperty, value: PropertyValue) =
  ## Set the value of a property
  # Use setter accessor if available
  if property.accessors.setter != nil:
    property.accessors.setter(value)
  else:
    # Default behavior: convert types if needed and assign
    if property.value.kind != value.kind:
      # Type mismatch, try to convert
      case property.value.kind
      of StringProperty:
        property.value.strValue = $value
      of IntProperty:
        property.value.intValue = value.asInt()
      of FloatProperty:
        property.value.floatValue = value.asFloat()
      of BoolProperty:
        property.value.boolValue = value.asBool()
      of CustomProperty:
        # Can't convert to custom
        return
    else:
      # Types match, just assign
      property.value = value
  
  # Notify
  property.notifyValueChanged()

proc setValue*(property: BindableProperty, value: string) =
  ## Set the value of a property to a string
  property.setValue(newPropertyValue(value))

proc setValue*(property: BindableProperty, value: int) =
  ## Set the value of a property to an int
  property.setValue(newPropertyValue(value))

proc setValue*(property: BindableProperty, value: float) =
  ## Set the value of a property to a float
  property.setValue(newPropertyValue(value))

proc setValue*(property: BindableProperty, value: bool) =
  ## Set the value of a property to a bool
  property.setValue(newPropertyValue(value))

proc getStringValue*(property: BindableProperty): string =
  ## Get the property value as a string
  return property.getValue().asString()

proc getIntValue*(property: BindableProperty): int =
  ## Get the property value as an int
  return property.getValue().asInt()

proc getFloatValue*(property: BindableProperty): float =
  ## Get the property value as a float
  return property.getValue().asFloat()

proc getBoolValue*(property: BindableProperty): bool =
  ## Get the property value as a bool
  return property.getValue().asBool()

proc newBindableProperty*(name: string, value: PropertyValue): BindableProperty =
  ## Create a new bindable property
  result = BindableProperty(
    name: name,
    value: value,
    bindings: @[]
  )

proc newStringProperty*(name: string, value: string = ""): BindableProperty =
  ## Create a new string property
  return newBindableProperty(name, newPropertyValue(value))

proc newIntProperty*(name: string, value: int = 0): BindableProperty =
  ## Create a new int property
  return newBindableProperty(name, newPropertyValue(value))

proc newFloatProperty*(name: string, value: float = 0.0): BindableProperty =
  ## Create a new float property
  return newBindableProperty(name, newPropertyValue(value))

proc newBoolProperty*(name: string, value: bool = false): BindableProperty =
  ## Create a new bool property
  return newBindableProperty(name, newPropertyValue(value))

proc setAccessors*(property: BindableProperty, 
                  getter: proc(): PropertyValue {.closure.} = nil,
                  setter: proc(value: PropertyValue) {.closure.} = nil,
                  notifier: proc() {.closure.} = nil) =
  ## Set property accessors
  property.accessors.getter = getter
  property.accessors.setter = setter
  property.accessors.notifier = notifier

#-----------------------------------------------------------------
# Binding
#-----------------------------------------------------------------

proc newBinding*(source, target: BindableProperty, 
                direction: BindingDirection = OneWayToTarget,
                valueConverter: proc(value: PropertyValue): PropertyValue {.closure.} = nil): Binding =
  ## Create a new property binding
  result = Binding(
    source: source,
    target: target,
    direction: direction,
    active: true,
    valueConverter: valueConverter
  )
  
  # Add binding to both properties
  source.bindings.add(result)
  if source != target:  # Avoid adding twice for self-bindings
    target.bindings.add(result)
  
  # Initialize target from source
  if direction in {OneWayToTarget, TwoWay}:
    var value = source.getValue()
    if valueConverter != nil:
      value = valueConverter(value)
    
    if target.accessors.setter != nil:
      target.accessors.setter(value)
    else:
      target.value = value
      target.notifyValueChanged()

proc activate*(binding: Binding) =
  ## Activate binding
  if not binding.active:
    binding.active = true
    # Initialize target from source
    if binding.direction in {OneWayToTarget, TwoWay}:
      var value = binding.source.getValue()
      if binding.valueConverter != nil:
        value = binding.valueConverter(value)
      
      if binding.target.accessors.setter != nil:
        binding.target.accessors.setter(value)
      else:
        binding.target.value = value
        binding.target.notifyValueChanged()

proc deactivate*(binding: Binding) =
  ## Deactivate binding
  binding.active = false

#-----------------------------------------------------------------
# Data Context
#-----------------------------------------------------------------

proc newDataContext*(): DataContext =
  ## Create a new data context
  result = DataContext(
    properties: initTable[string, BindableProperty]()
  )

proc addProperty*(context: DataContext, property: BindableProperty) =
  ## Add a property to the data context
  context.properties[property.name] = property

proc getProperty*(context: DataContext, name: string): Option[BindableProperty] =
  ## Get a property from the data context
  if context.properties.hasKey(name):
    return some(context.properties[name])
  return none(BindableProperty)

proc setProperty*(context: DataContext, name: string, value: PropertyValue) =
  ## Set a property value in the data context
  if context.properties.hasKey(name):
    context.properties[name].setValue(value)

proc setStringProperty*(context: DataContext, name: string, value: string) =
  ## Set a string property value
  if context.properties.hasKey(name):
    context.properties[name].setValue(value)

proc setIntProperty*(context: DataContext, name: string, value: int) =
  ## Set an int property value
  if context.properties.hasKey(name):
    context.properties[name].setValue(value)

proc setFloatProperty*(context: DataContext, name: string, value: float) =
  ## Set a float property value
  if context.properties.hasKey(name):
    context.properties[name].setValue(value)

proc setBoolProperty*(context: DataContext, name: string, value: bool) =
  ## Set a bool property value
  if context.properties.hasKey(name):
    context.properties[name].setValue(value)

proc setPropertyValue*(context: DataContext, name: string, value: PropertyValue) =
  ## Set a property value by name
  if context.properties.hasKey(name):
    context.properties[name].setValue(value)

#-----------------------------------------------------------------
# Binding Manager
#-----------------------------------------------------------------

proc newBindingManager*(): BindingManager =
  ## Create a new binding manager
  result = BindingManager(
    bindings: @[],
    contexts: initTable[string, DataContext]()
  )

proc addContext*(manager: BindingManager, name: string, context: DataContext) =
  ## Add a data context
  manager.contexts[name] = context

proc getContext*(manager: BindingManager, name: string): Option[DataContext] =
  ## Get a data context by name
  if manager.contexts.hasKey(name):
    return some(manager.contexts[name])
  return none(DataContext)

proc createBinding*(manager: BindingManager, 
                   source: BindableProperty, 
                   target: BindableProperty,
                   direction: BindingDirection = OneWayToTarget,
                   valueConverter: proc(value: PropertyValue): PropertyValue {.closure.} = nil): Binding =
  ## Create and register a binding
  let binding = newBinding(source, target, direction, valueConverter)
  manager.bindings.add(binding)
  return binding

proc createPropertyPathBinding*(manager: BindingManager,
                              sourceContextName: string, sourcePath: string,
                              targetContextName: string, targetPath: string,
                              direction: BindingDirection = OneWayToTarget): Option[Binding] =
  ## Create a binding between two property paths
  if not manager.contexts.hasKey(sourceContextName) or 
     not manager.contexts.hasKey(targetContextName):
    return none(Binding)
  
  let sourceContext = manager.contexts[sourceContextName]
  let targetContext = manager.contexts[targetContextName]
  
  # Simple case - direct property binding
  if not sourcePath.contains('.') and not targetPath.contains('.'):
    let sourceOpt = sourceContext.getProperty(sourcePath)
    let targetOpt = targetContext.getProperty(targetPath)
    
    if sourceOpt.isNone or targetOpt.isNone:
      return none(Binding)
    
    let binding = manager.createBinding(sourceOpt.get, targetOpt.get, direction)
    return some(binding)
  
  # TODO: Implement more complex property path traversal
  # For nested properties like "person.address.city"
  
  return none(Binding)

proc bindPropertyPath*(manager: BindingManager, 
                      sourcePath: string,
                      target: BindableProperty,
                      direction: BindingDirection = OneWayToTarget,
                      valueConverter: proc(value: PropertyValue): PropertyValue {.closure.} = nil): Option[Binding] =
  ## Bind a property path to a target property
  # Parse the path (e.g., "user.title")
  let pathParts = sourcePath.split('.')
  if pathParts.len == 0:
    return none(Binding)
  
  let contextName = pathParts[0]
  
  # Get the context
  if not manager.contexts.hasKey(contextName):
    return none(Binding)
  
  let context = manager.contexts[contextName]
  
  # Handle simple property access (e.g., "user.title")
  if pathParts.len == 2:
    let propertyName = pathParts[1]
    let sourceOpt = context.getProperty(propertyName)
    if sourceOpt.isNone:
      return none(Binding)
    
    let binding = manager.createBinding(sourceOpt.get, target, direction, valueConverter)
    return some(binding)
  
  # TODO: Handle nested property paths
  return none(Binding)

#-----------------------------------------------------------------
# Widget Integration
#-----------------------------------------------------------------

proc setDataContext*(widget: Widget, context: DataContext) =
  ## Set a data context on a widget
  if widget.state == nil:
    widget.state = WidgetState()
  widget.state.dataContext = cast[pointer](context)

proc getDataContext*(widget: Widget): DataContext =
  ## Get the data context from a widget
  if widget.state.dataContext != nil:
    return cast[DataContext](widget.state.dataContext)
  
  # Try to get from parent if not found
  if widget.parent != nil:
    return widget.parent.getDataContext()
  
  return nil

proc bindProperty*(widget: Widget, 
                  widgetPropertyName: string,
                  contextPropertyName: string,
                  direction: BindingDirection = TwoWay): Option[Binding] =
  ## Bind a widget property to a data context property
  let context = widget.getDataContext()
  if context == nil:
    return none(Binding)
  
  let contextPropOpt = context.getProperty(contextPropertyName)
  if contextPropOpt.isNone:
    return none(Binding)
  
  let contextProp = contextPropOpt.get
  
  # Create a widget property if it doesn't exist yet
  if not widget.properties.hasKey(widgetPropertyName):
    # Create property with same type as context property
    var widgetProp: BindableProperty
    case contextProp.value.kind
    of StringProperty:
      widgetProp = newStringProperty(widgetPropertyName)
    of IntProperty:
      widgetProp = newIntProperty(widgetPropertyName)
    of FloatProperty:
      widgetProp = newFloatProperty(widgetPropertyName)
    of BoolProperty:
      widgetProp = newBoolProperty(widgetPropertyName)
    of CustomProperty:
      widgetProp = newBindableProperty(widgetPropertyName, 
                                     newCustomPropertyValue(nil))
    
    widget.properties[widgetPropertyName] = cast[pointer](widgetProp)
  
  # Create binding
  let binding = newBinding(contextProp, cast[BindableProperty](widget.properties[widgetPropertyName]), direction)
  return some(binding)

# Add properties field to Widget type
# This would normally be done in the widgets.nim file
# But we'll patch it here for demonstration purposes
proc initProperties*(widget: Widget) =
  ## Initialize the properties table for a widget
  widget.properties = initTable[string, pointer]()

proc getProperty*(widget: Widget, name: string): Option[BindableProperty] =
  ## Get a property from a widget
  if widget.properties.hasKey(name):
    return some(cast[BindableProperty](widget.properties[name]))
  return none(BindableProperty)

#-----------------------------------------------------------------
# Common Widget Property Binding
#-----------------------------------------------------------------

# These would normally be defined in each widget implementation file
# But we'll define them here for demonstration purposes

# proc bindText*(label: Widget, contextPropertyName: string): Option[Binding] =
#   ## Bind a label's text to a context property
#   # NOTE: This function is commented out because it depends on methods
#   # (getText, setText, markDirty) that are not yet implemented in the widget system
#   discard

# proc bindChecked*(checkbox: Widget, contextPropertyName: string): Option[Binding] =
#   ## Bind a checkbox's checked state to a context property  
#   # NOTE: This function is commented out because it depends on methods
#   # (isChecked, setChecked, markDirty) that are not yet implemented in the widget system
#   discard

# proc bindEnabled*(widget: Widget, contextPropertyName: string): Option[Binding] =
#   ## Bind a widget's enabled state to a context property
#   # NOTE: This function is commented out because it depends on methods
#   # (isEnabled, setEnabled, markDirty) that are not yet implemented in the widget system
#   discard

# All the following binding functions are commented out because they depend on
# widget methods that are not yet implemented in the widget system
# (isVisible, setVisible, getProgress, setProgress, markDirty, etc.)

# proc bindVisible*(widget: Widget, contextPropertyName: string): Option[Binding] =
#   discard

# proc bindProgress*(progressBar: Widget, contextPropertyName: string): Option[Binding] =
#   discard

# proc bindValue*(widget: Widget, contextPropertyName: string): Option[Binding] = 
#   discard