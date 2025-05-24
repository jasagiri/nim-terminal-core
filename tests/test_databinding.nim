# test_databinding.nim
## データバインディングのテスト

import unittest
import std/tables
import std/options

import ../src/libterminal
import ../src/libterminal/databinding
import ../src/libterminal/widget_base
import ../src/libterminal/widgets

suite "プロパティ値":
  test "プロパティ値の作成と取得":
    # 文字列プロパティ
    let strValue = newPropertyValue("Hello")
    check(strValue.kind == StringProperty)
    check(strValue.asString() == "Hello")
    
    # 整数プロパティ
    let intValue = newPropertyValue(42)
    check(intValue.kind == IntProperty)
    check(intValue.asInt() == 42)
    
    # 浮動小数点プロパティ
    let floatValue = newPropertyValue(3.14)
    check(floatValue.kind == FloatProperty)
    check(floatValue.asFloat() == 3.14)
    
    # 真偽値プロパティ
    let boolValue = newPropertyValue(true)
    check(boolValue.kind == BoolProperty)
    check(boolValue.asBool())
  
  test "プロパティ値の変換":
    # 文字列からの変換
    let strValue = newPropertyValue("42")
    check(strValue.asInt() == 42)
    check(strValue.asFloat() == 42.0)
    check(strValue.asBool())  # 空でない文字列はtrue
    
    # 整数からの変換
    let intValue = newPropertyValue(0)
    check(intValue.asString() == "0")
    check(intValue.asFloat() == 0.0)
    check(not intValue.asBool())  # 0はfalse
    
    # 浮動小数点からの変換
    let floatValue = newPropertyValue(3.14)
    check(floatValue.asString() == "3.14")
    check(floatValue.asInt() == 3)
    check(floatValue.asBool())  # 0以外はtrue
    
    # 真偽値からの変換
    let boolValue = newPropertyValue(false)
    check(boolValue.asString() == "false")
    check(boolValue.asInt() == 0)
    check(boolValue.asFloat() == 0.0)

suite "バインド可能プロパティ":
  test "バインド可能プロパティの作成と値の取得設定":
    # 文字列プロパティの作成
    let textProp = newStringProperty("text")
    check(textProp.name == "text")
    check(textProp.value.kind == StringProperty)
    check(textProp.value.asString() == "")  # 初期値は空文字列
    
    # 値の設定
    textProp.setValue(newPropertyValue("Hello"))
    check(textProp.getValue().asString() == "Hello")
    
    # 整数プロパティ
    let countProp = newIntProperty("count")
    check(countProp.name == "count")
    check(countProp.value.kind == IntProperty)
    check(countProp.value.asInt() == 0)  # 初期値は0
    
    countProp.setValue(newPropertyValue(5))
    check(countProp.getValue().asInt() == 5)
    
    # 真偽値プロパティ
    let enabledProp = newBoolProperty("enabled")
    check(enabledProp.name == "enabled")
    check(enabledProp.value.kind == BoolProperty)
    check(not enabledProp.getValue().asBool())  # 初期値はfalse
    
    enabledProp.setValue(newPropertyValue(true))
    check(enabledProp.getValue().asBool())

  test "プロパティのアクセサ":
    var getterCalled = false
    var setterCalled = false
    var notifierCalled = false
    var storedValue = newPropertyValue("")
    
    # アクセサ関数を持つプロパティ
    let prop = newStringProperty("test")
    
    # アクセサの設定
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
    
    # ゲッターのテスト
    discard prop.getValue()
    check(getterCalled)
    
    # セッターのテスト
    prop.setValue(newPropertyValue("Updated"))
    check(setterCalled)
    
    # 値が更新されたことを確認 (storedValueはセッターによって更新されているはず)
    getterCalled = false
    
    let value = prop.getValue()
    check(getterCalled)
    check(value.asString() == "Updated")
    
    # 通知のテスト
    notifierCalled = false
    prop.notifyValueChanged()
    check(notifierCalled)

suite "バインディング":
  test "一方向バインディング":
    # ソースプロパティ
    let source = newStringProperty("source")
    source.setValue(newPropertyValue("Initial Value"))
    
    # ターゲットプロパティ
    let target = newStringProperty("target")
    
    # 一方向バインディングを作成
    let binding = newBinding(source, target, OneWayToTarget)
    
    # 初期値が反映されることを確認
    check(target.getValue().asString() == "Initial Value")
    
    # ソースを変更するとターゲットに反映される
    source.setValue(newPropertyValue("Updated Source"))
    source.notifyValueChanged()
    
    check(target.getValue().asString() == "Updated Source")
    
    # ターゲットを変更してもソースには反映されない
    target.setValue(newPropertyValue("Updated Target"))
    target.notifyValueChanged()
    
    check(source.getValue().asString() == "Updated Source")  # 変化なし

  test "双方向バインディング":
    # ソースプロパティ
    let source = newIntProperty("source")
    source.setValue(newPropertyValue(10))
    
    # ターゲットプロパティ
    let target = newIntProperty("target")
    
    # 双方向バインディングを作成
    let binding = newBinding(source, target, TwoWay)
    
    # 初期値が反映されることを確認
    check(target.getValue().asInt() == 10)
    
    # ソースを変更するとターゲットに反映される
    source.setValue(newPropertyValue(20))
    source.notifyValueChanged()
    
    check(target.getValue().asInt() == 20)
    
    # ターゲットを変更するとソースにも反映される
    target.setValue(newPropertyValue(30))
    target.notifyValueChanged()
    
    check(source.getValue().asInt() == 30)

  test "値コンバータ付きバインディング":
    # ソースプロパティ（整数）
    let source = newIntProperty("source")
    source.setValue(newPropertyValue(42))
    
    # ターゲットプロパティ（文字列）
    let target = newStringProperty("target")
    
    # 整数→文字列のコンバータ
    proc intToStringConverter(value: PropertyValue): PropertyValue =
      let intValue = value.asInt()
      return newPropertyValue($intValue & " items")
    
    # コンバータ付きの一方向バインディングを作成
    let binding = newBinding(source, target, OneWayToTarget, intToStringConverter)
    
    # 初期値が変換されて反映されることを確認
    check(target.getValue().asString() == "42 items")
    
    # ソースを変更するとターゲットに変換されて反映される
    source.setValue(newPropertyValue(100))
    source.notifyValueChanged()
    
    check(target.getValue().asString() == "100 items")

suite "データコンテキスト":
  test "データコンテキストの作成と取得":
    let context = newDataContext()
    check(context != nil)
    check(context.properties.len == 0)
    
    # プロパティの追加
    let nameProp = newStringProperty("name")
    nameProp.setValue(newPropertyValue("John"))
    
    let ageProp = newIntProperty("age")
    ageProp.setValue(newPropertyValue(30))
    
    context.addProperty(nameProp)
    context.addProperty(ageProp)
    
    check(context.properties.len == 2)
    check(context.properties.hasKey("name"))
    check(context.properties.hasKey("age"))
    
    # プロパティの取得
    let nameResult = context.getProperty("name")
    check(nameResult.isSome)
    check(nameResult.get().getValue().asString() == "John")
    
    let ageResult = context.getProperty("age")
    check(ageResult.isSome)
    check(ageResult.get().getValue().asInt() == 30)
    
    # 存在しないプロパティ
    check(context.getProperty("unknown").isNone)
    
    # プロパティの更新
    context.setProperty("name", newPropertyValue("Jane"))
    let updatedName = context.getProperty("name")
    check(updatedName.isSome)
    check(updatedName.get().getValue().asString() == "Jane")

suite "バインディングマネージャ":
  test "バインディングマネージャの作成と管理":
    let manager = newBindingManager()
    check(manager != nil)
    check(manager.bindings.len == 0)
    check(manager.contexts.len == 0)
    
    # データコンテキストの追加
    let userContext = newDataContext()
    let nameProp = newStringProperty("name")
    nameProp.setValue(newPropertyValue("John"))
    userContext.addProperty(nameProp)
    
    manager.addContext("user", userContext)
    check(manager.contexts.len == 1)
    check(manager.contexts.hasKey("user"))
    
    # コンテキストの取得
    let context = manager.getContext("user")
    check(context.isSome)
    
    # バインディングの作成
    let targetProp = newStringProperty("displayName")
    let binding = manager.createBinding(nameProp, targetProp)
    
    check(manager.bindings.len == 1)
    check(binding.source == nameProp)
    check(binding.target == targetProp)
    
    # パスによるバインディング
    let titleProp = newStringProperty("title")
    titleProp.setValue(newPropertyValue("Mr."))
    userContext.addProperty(titleProp)
    
    let fullNameProp = newStringProperty("fullName")
    
    proc fullNameConverter(value: PropertyValue): PropertyValue =
      let title = value.asString()
      let name = nameProp.getValue().asString()
      return newPropertyValue(title & " " & name)
    
    # パスを使用したバインディング（コンバータ付き）
    let binding2Result = manager.bindPropertyPath(
      "user.title",
      fullNameProp,
      OneWayToTarget,
      fullNameConverter
    )
    
    check(binding2Result.isSome)
    check(fullNameProp.getValue().asString() == "Mr. John")
    
    # コンテキストの値を変更すると、バインドされたプロパティも更新される
    userContext.setPropertyValue("title", newPropertyValue("Dr."))
    check(fullNameProp.getValue().asString() == "Dr. John")

suite "ウィジェットへのバインディング":
  test "ウィジェットプロパティへのバインディング":
    # ウィジェットの作成
    let widget = newWidget("testWidget", 0, 0, 10, 10)
    initProperties(widget)
    
    # データコンテキストの設定
    let dataContext = newDataContext()
    let textProp = newStringProperty("text")
    textProp.setValue(newPropertyValue("Hello World"))
    dataContext.addProperty(textProp)
    
    setDataContext(widget, dataContext)
    
    # ウィジェットのプロパティを作成
    let widgetProp = newStringProperty("text")
    widget.properties["text"] = cast[pointer](widgetProp)
    
    # バインディングの作成
    let bindingResult = widget.bindProperty("text", "text")
    check(bindingResult.isSome)
    
    # データコンテキストの値がウィジェットのプロパティに反映される
    check(widgetProp.getValue().asString() == "Hello World")
    
    # データコンテキストの値を変更
    textProp.setValue(newPropertyValue("Updated Text"))
    textProp.notifyValueChanged()
    
    check(widgetProp.getValue().asString() == "Updated Text")