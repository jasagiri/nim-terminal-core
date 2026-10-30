# test_databinding.nim
## Data binding tests

import unittest
import std/tables
import std/options

import ../src/libterminal
import ../src/libterminal/databinding
import ../src/libterminal/widget_base
import ../src/libterminal/widgets

suite "Property values":
  test "Property value creation and retrieval":
    # String property
    let strValue = newPropertyValue("Hello")
    check(strValue.kind == StringProperty)
    check(strValue.asString() == "Hello")
    
    # Integer property
    let intValue = newPropertyValue(42)
    check(intValue.kind == IntProperty)
    check(intValue.asInt() == 42)
    
    # Floating point property
    let floatValue = newPropertyValue(3.14)
    check(floatValue.kind == FloatProperty)
    check(floatValue.asFloat() == 3.14)
    
    # Boolean property
    let boolValue = newPropertyValue(true)
    check(boolValue.kind == BoolProperty)
    check(boolValue.asBool())
  
  test "Property value conversion":
    # Conversion from string
    let strValue = newPropertyValue("42")
    check(strValue.asInt() == 42)
    check(strValue.asFloat() == 42.0)
    check(strValue.asBool())  # Non-empty string is true
    
    # Conversion from integer
    let intValue = newPropertyValue(0)
    check(intValue.asString() == "0")
    check(intValue.asFloat() == 0.0)
    check(not intValue.asBool())  # 0 is false
    
    # Conversion from floating point
    let floatValue = newPropertyValue(3.14)
    check(floatValue.asString() == "3.14")
    check(floatValue.asInt() == 3)
    check(floatValue.asBool())  # Non-zero is true
    
    # Conversion from boolean
    let boolValue = newPropertyValue(false)
    check(boolValue.asString() == "false")
    check(boolValue.asInt() == 0)
    check(boolValue.asFloat() == 0.0)

suite "Bindable properties":
  test "Bindable property creation and value get/set":
    # Create string property
    let textProp = newStringProperty("text")
    check(textProp.name == "text")
    check(textProp.value.kind == StringProperty)
    check(textProp.value.asString() == "")  # Initial value is empty string
    
    # Set value
    textProp.setValue(newPropertyValue("Hello"))
    check(textProp.getValue().asString() == "Hello")
    
    # Integer property
    let countProp = newIntProperty("count")
    check(countProp.name == "count")
    check(countProp.value.kind == IntProperty)
    check(countProp.value.asInt() == 0)  # Initial value is 0
    
    countProp.setValue(newPropertyValue(5))
    check(countProp.getValue().asInt() == 5)
    
    # Boolean property
    let enabledProp = newBoolProperty("enabled")
    check(enabledProp.name == "enabled")
    check(enabledProp.value.kind == BoolProperty)
    check(not enabledProp.getValue().asBool())  # Initial value is false
    
    enabledProp.setValue(newPropertyValue(true))
    check(enabledProp.getValue().asBool())

  test "Property accessors":
    var getterCalled = false
    var setterCalled = false
    var notifierCalled = false
    var storedValue = newPropertyValue("")
    
    # Property with accessor functions
    let prop = newStringProperty("test")
    
    # Set accessors
    prop.setAccessors(
      getter = proc(): PropertyValue =
        getterCalled = true
        return storedValue
      ,
      setter = proc(value: PropertyValue) =
        setterCalled = true
        storedValue = value
      ,
      notifier = proc() =
        notifierCalled = true
    )
    
    # Test getter
    discard prop.getValue()
    check(getterCalled)
    
    # Test setter
    prop.setValue(newPropertyValue("Updated"))
    check(setterCalled)
    
    # Verify value was updated (storedValue should have been updated by setter)
    getterCalled = false
    
    let value = prop.getValue()
    check(getterCalled)
    check(value.asString() == "Updated")
    
    # Test notification
    notifierCalled = false
    prop.notifyValueChanged()
    check(notifierCalled)

suite "Binding":
  test "One-way binding":
    # Source property
    let source = newStringProperty("source")
    source.setValue(newPropertyValue("Initial Value"))
    
    # Target property
    let target = newStringProperty("target")
    
    # Create one-way binding
    let binding = newBinding(source, target, OneWayToTarget)
    
    # Verify initial value is reflected
    check(target.getValue().asString() == "Initial Value")
    
    # Changing source is reflected to target
    source.setValue(newPropertyValue("Updated Source"))
    source.notifyValueChanged()
    
    check(target.getValue().asString() == "Updated Source")
    
    # Changing target is not reflected to source
    target.setValue(newPropertyValue("Updated Target"))
    target.notifyValueChanged()
    
    check(source.getValue().asString() == "Updated Source")  # No change

  test "Two-way binding":
    # Source property
    let source = newIntProperty("source")
    source.setValue(newPropertyValue(10))
    
    # Target property
    let target = newIntProperty("target")
    
    # Create two-way binding
    let binding = newBinding(source, target, TwoWay)
    
    # Verify initial value is reflected
    check(target.getValue().asInt() == 10)
    
    # Changing source is reflected to target
    source.setValue(newPropertyValue(20))
    source.notifyValueChanged()
    
    check(target.getValue().asInt() == 20)
    
    # Changing target is also reflected to source
    target.setValue(newPropertyValue(30))
    target.notifyValueChanged()
    
    check(source.getValue().asInt() == 30)

  test "Binding with value converter":
    # Source property (integer)
    let source = newIntProperty("source")
    source.setValue(newPropertyValue(42))
    
    # Target property (string)
    let target = newStringProperty("target")
    
    # Integer to string converter
    proc intToStringConverter(value: PropertyValue): PropertyValue =
      let intValue = value.asInt()
      return newPropertyValue($intValue & " items")
    
    # Create one-way binding with converter
    let binding = newBinding(source, target, OneWayToTarget, intToStringConverter)
    
    # Verify initial value is converted and reflected
    check(target.getValue().asString() == "42 items")
    
    # Changing source is converted and reflected to target
    source.setValue(newPropertyValue(100))
    source.notifyValueChanged()
    
    check(target.getValue().asString() == "100 items")

suite "Data context":
  test "Data context creation and retrieval":
    let context = newDataContext()
    check(context != nil)
    check(context.properties.len == 0)
    
    # Add properties
    let nameProp = newStringProperty("name")
    nameProp.setValue(newPropertyValue("John"))
    
    let ageProp = newIntProperty("age")
    ageProp.setValue(newPropertyValue(30))
    
    context.addProperty(nameProp)
    context.addProperty(ageProp)
    
    check(context.properties.len == 2)
    check(context.properties.hasKey("name"))
    check(context.properties.hasKey("age"))
    
    # Get properties
    let nameResult = context.getProperty("name")
    check(nameResult.isSome)
    check(nameResult.get().getValue().asString() == "John")
    
    let ageResult = context.getProperty("age")
    check(ageResult.isSome)
    check(ageResult.get().getValue().asInt() == 30)
    
    # Non-existent property
    check(context.getProperty("unknown").isNone)
    
    # Update property
    context.setProperty("name", newPropertyValue("Jane"))
    let updatedName = context.getProperty("name")
    check(updatedName.isSome)
    check(updatedName.get().getValue().asString() == "Jane")

suite "Binding manager":
  test "Binding manager creation and management":
    let manager = newBindingManager()
    check(manager != nil)
    check(manager.bindings.len == 0)
    check(manager.contexts.len == 0)
    
    # Add data context
    let userContext = newDataContext()
    let nameProp = newStringProperty("name")
    nameProp.setValue(newPropertyValue("John"))
    userContext.addProperty(nameProp)
    
    manager.addContext("user", userContext)
    check(manager.contexts.len == 1)
    check(manager.contexts.hasKey("user"))
    
    # Get context
    let context = manager.getContext("user")
    check(context.isSome)
    
    # Create binding
    let targetProp = newStringProperty("displayName")
    let binding = manager.createBinding(nameProp, targetProp)
    
    check(manager.bindings.len == 1)
    check(binding.source == nameProp)
    check(binding.target == targetProp)
    
    # Path-based binding
    let titleProp = newStringProperty("title")
    titleProp.setValue(newPropertyValue("Mr."))
    userContext.addProperty(titleProp)
    
    let fullNameProp = newStringProperty("fullName")
    
    proc fullNameConverter(value: PropertyValue): PropertyValue =
      let title = value.asString()
      let name = nameProp.getValue().asString()
      return newPropertyValue(title & " " & name)
    
    # Path-based binding with converter
    let binding2Result = manager.bindPropertyPath(
      "user.title",
      fullNameProp,
      OneWayToTarget,
      fullNameConverter
    )
    
    check(binding2Result.isSome)
    check(fullNameProp.getValue().asString() == "Mr. John")
    
    # Changing context value updates bound property
    userContext.setPropertyValue("title", newPropertyValue("Dr."))
    check(fullNameProp.getValue().asString() == "Dr. John")

suite "Widget binding":
  test "Binding to widget properties":
    # Create widget
    let widget = newWidget("testWidget", 0, 0, 10, 10)
    initProperties(widget)
    
    # Set data context
    let dataContext = newDataContext()
    let textProp = newStringProperty("text")
    textProp.setValue(newPropertyValue("Hello World"))
    dataContext.addProperty(textProp)
    
    setDataContext(widget, dataContext)
    
    # Create widget property
    let widgetProp = newStringProperty("text")
    widget.properties["text"] = cast[pointer](widgetProp)
    
    # Create binding
    let bindingResult = widget.bindProperty("text", "text")
    check(bindingResult.isSome)
    
    # Data context value is reflected to widget property
    check(widgetProp.getValue().asString() == "Hello World")
    
    # Change data context value
    textProp.setValue(newPropertyValue("Updated Text"))
    textProp.notifyValueChanged()
    
    check(widgetProp.getValue().asString() == "Updated Text")