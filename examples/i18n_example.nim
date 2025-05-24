# i18n_example.nim
## Internationalization and Localization Demo
## 
## This example demonstrates internationalization capabilities
## with proper handling of various languages and locales.

import libterminal
import std/unicode
import std/tables
import std/strutils
import std/times

type
  Language = enum
    English, Japanese, Arabic, Russian, 
    Spanish, Chinese, Korean, Hindi, Hebrew

  TranslationKey = enum
    Welcome, Language, Settings, DateTime,
    Calendar, Yes, No, Cancel, Help, About,
    File, Edit, View, Tools, Info, Error, Warning

# Translations for each language
let translations = {
  English: {
    Welcome:  "Welcome to libterminal i18n demo",
    Language: "Language",
    Settings: "Settings",
    DateTime: "Date & Time",
    Calendar: "Calendar",
    Yes:      "Yes",
    No:       "No",
    Cancel:   "Cancel",
    Help:     "Help",
    About:    "About",
    File:     "File",
    Edit:     "Edit",
    View:     "View",
    Tools:    "Tools",
    Info:     "Information",
    Error:    "Error",
    Warning:  "Warning"
  }.toTable,
  
  Japanese: {
    Welcome:  "terminとデモへようこそ",
    Language: "言語",
    Settings: "設定",
    DateTime: "日付と時刻",
    Calendar: "カレンダー",
    Yes:      "はい",
    No:       "いいえ",
    Cancel:   "キャンセル",
    Help:     "ヘルプ",
    About:    "概要",
    File:     "ファイル",
    Edit:     "編集",
    View:     "表示",
    Tools:    "ツール",
    Info:     "情報",
    Error:    "エラー",
    Warning:  "警告"
  }.toTable,
  
  Arabic: {
    Welcome:  "مرحبًا بكم في عرض توطين libterminal",
    Language: "اللغة",
    Settings: "الإعدادات",
    DateTime: "التاريخ والوقت",
    Calendar: "التقويم",
    Yes:      "نعم",
    No:       "لا",
    Cancel:   "إلغاء",
    Help:     "مساعدة",
    About:    "حول",
    File:     "ملف",
    Edit:     "تحرير",
    View:     "عرض",
    Tools:    "أدوات",
    Info:     "معلومات",
    Error:    "خطأ",
    Warning:  "تحذير"
  }.toTable,
  
  Russian: {
    Welcome:  "Добро пожаловать в демо локализации libterminal",
    Language: "Язык",
    Settings: "Настройки",
    DateTime: "Дата и время",
    Calendar: "Календарь",
    Yes:      "Да",
    No:       "Нет",
    Cancel:   "Отмена",
    Help:     "Помощь",
    About:    "О программе",
    File:     "Файл",
    Edit:     "Редактировать",
    View:     "Вид",
    Tools:    "Инструменты",
    Info:     "Информация",
    Error:    "Ошибка",
    Warning:  "Предупреждение"
  }.toTable,
  
  Spanish: {
    Welcome:  "Bienvenido a la demostración de i18n de libterminal",
    Language: "Idioma",
    Settings: "Configuración",
    DateTime: "Fecha y hora",
    Calendar: "Calendario",
    Yes:      "Sí",
    No:       "No",
    Cancel:   "Cancelar",
    Help:     "Ayuda",
    About:    "Acerca de",
    File:     "Archivo",
    Edit:     "Editar",
    View:     "Ver",
    Tools:    "Herramientas",
    Info:     "Información",
    Error:    "Error",
    Warning:  "Advertencia"
  }.toTable,
  
  Chinese: {
    Welcome:  "欢迎使用 libterminal 国际化演示",
    Language: "语言",
    Settings: "设置",
    DateTime: "日期和时间",
    Calendar: "日历",
    Yes:      "是",
    No:       "否",
    Cancel:   "取消",
    Help:     "帮助",
    About:    "关于",
    File:     "文件",
    Edit:     "编辑",
    View:     "查看",
    Tools:    "工具",
    Info:     "信息",
    Error:    "错误",
    Warning:  "警告"
  }.toTable,
  
  Korean: {
    Welcome:  "libterminal 국제화 데모에 오신 것을 환영합니다",
    Language: "언어",
    Settings: "설정",
    DateTime: "날짜 및 시간",
    Calendar: "달력",
    Yes:      "예",
    No:       "아니오",
    Cancel:   "취소",
    Help:     "도움말",
    About:    "정보",
    File:     "파일",
    Edit:     "편집",
    View:     "보기",
    Tools:    "도구",
    Info:     "정보",
    Error:    "오류",
    Warning:  "경고"
  }.toTable,
  
  Hindi: {
    Welcome:  "libterminal अंतर्राष्ट्रीयकरण डेमो में आपका स्वागत है",
    Language: "भाषा",
    Settings: "सेटिंग्स",
    DateTime: "दिनांक और समय",
    Calendar: "कैलेंडर",
    Yes:      "हां",
    No:       "नहीं",
    Cancel:   "रद्द करें",
    Help:     "सहायता",
    About:    "के बारे में",
    File:     "फ़ाइल",
    Edit:     "संपादित करें",
    View:     "देखें",
    Tools:    "उपकरण",
    Info:     "जानकारी",
    Error:    "त्रुटि",
    Warning:  "चेतावनी"
  }.toTable,
  
  Hebrew: {
    Welcome:  "ברוכים הבאים להדגמת בינאום של libterminal",
    Language: "שפה",
    Settings: "הגדרות",
    DateTime: "תאריך ושעה",
    Calendar: "לוח שנה",
    Yes:      "כן",
    No:       "לא",
    Cancel:   "ביטול",
    Help:     "עזרה",
    About:    "אודות",
    File:     "קובץ",
    Edit:     "עריכה",
    View:     "תצוגה",
    Tools:    "כלים",
    Info:     "מידע",
    Error:    "שגיאה",
    Warning:  "אזהרה"
  }.toTable
}.toTable

# Date formatting by language
proc formatDate(dt: DateTime, lang: Language): string =
  case lang
  of English:
    return dt.format("MMMM d, yyyy")
  of Japanese:
    return dt.format("yyyy年MM月dd日")
  of Arabic:
    # Arabic date format
    let monthNames = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", 
                      "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
    return $dt.year & " " & monthNames[dt.month.int - 1] & " " & $dt.monthday
  of Russian:
    return dt.format("d MMMM yyyy г.")
  of Spanish:
    return dt.format("d 'de' MMMM 'de' yyyy")
  of Chinese:
    return dt.format("yyyy年MM月dd日")
  of Korean:
    return dt.format("yyyy년 MM월 dd일")
  of Hindi:
    # Hindi date format
    let monthNames = ["जनवरी", "फरवरी", "मार्च", "अप्रैल", "मई", "जून", 
                     "जुलाई", "अगस्त", "सितंबर", "अक्टूबर", "नवंबर", "दिसंबर"]
    return $dt.monthday & " " & monthNames[dt.month.int - 1] & " " & $dt.year
  of Hebrew:
    # Hebrew date format (simplified, not using Hebrew calendar)
    return dt.format("d MMMM yyyy")

# Time formatting by language
proc formatTime(dt: DateTime, lang: Language): string =
  case lang
  of English:
    return dt.format("h:mm:ss a")
  of Japanese, Chinese, Korean:
    return dt.format("HH時mm分ss秒")
  of Arabic, Hebrew:
    # 24-hour format for Arabic and Hebrew
    return dt.format("HH:mm:ss")
  of Russian:
    return dt.format("HH:mm:ss")
  of Spanish:
    return dt.format("HH:mm:ss")
  of Hindi:
    return dt.format("HH:mm:ss")

# Get text direction for a language
proc getTextDirection(lang: Language): string =
  case lang
  of Arabic, Hebrew:
    return "RTL (Right-to-Left)"
  else:
    return "LTR (Left-to-Right)"

# Draw a menu with proper alignment
proc drawMenu(buffer: var Buffer, startX, startY: int, 
             items: seq[TranslationKey], lang: Language, 
             selectedIndex: int) =
  let isRTL = lang in {Arabic, Hebrew}
  let menuWidth = 20
  
  for i, item in items:
    let text = translations[lang][item]
    let style = if i == selectedIndex: 
                  Style(fg: ColorBlack, bg: ColorWhite)
                else:
                  Style(fg: ColorWhite, bg: ColorBlue)
    
    # RTL languages have different alignment
    if isRTL:
      # For RTL, right-align the text (padding on the left)
      let padding = menuWidth - displayWidth(text)
      let paddedText = " ".repeat(max(0, padding)) & text
      buffer.printAdvanced(startX, startY + i, paddedText, style)
    else:
      # For LTR, left-align with padding on the right
      buffer.printAdvanced(startX, startY + i, text & " ".repeat(max(0, menuWidth - displayWidth(text))), style)

# Draw a simple dialog box
proc drawDialog(buffer: var Buffer, title: string, message: string, 
               buttons: seq[TranslationKey], lang: Language) =
  let isRTL = lang in {Arabic, Hebrew}
  
  # Calculate dimensions
  let width = max(40, displayWidth(title) + 4, displayWidth(message) + 4)
  let height = 6 + countLines(message)
  
  let startX = (buffer.width - width) div 2
  let startY = (buffer.height - height) div 2
  
  # Draw border
  buffer.print(startX, startY, "┌" & "─".repeat(width - 2) & "┐")
  for i in 1..<height-1:
    buffer.print(startX, startY + i, "│" & " ".repeat(width - 2) & "│")
  buffer.print(startX, startY + height - 1, "└" & "─".repeat(width - 2) & "┘")
  
  # Draw title
  if isRTL:
    # For RTL, right-align the title
    let padding = width - 4 - displayWidth(title)
    buffer.print(startX + 2 + padding, startY, title, Style(fg: ColorYellow, attrs: {AttrBold}))
  else:
    buffer.print(startX + 2, startY, title, Style(fg: ColorYellow, attrs: {AttrBold}))
  
  # Draw message
  let msgLines = message.split('\n')
  for i, line in msgLines:
    if isRTL:
      # For RTL, right-align the message
      let padding = width - 4 - displayWidth(line)
      buffer.printAdvanced(startX + 2 + padding, startY + 2 + i, line)
    else:
      buffer.printAdvanced(startX + 2, startY + 2 + i, line)
  
  # Draw buttons
  let buttonWidth = 10
  let totalButtonWidth = buttons.len * buttonWidth + (buttons.len - 1) * 2
  let buttonStartX = startX + (width - totalButtonWidth) div 2
  
  for i, button in buttons:
    let buttonText = translations[lang][button]
    # Center the text within button
    let textPadding = (buttonWidth - displayWidth(buttonText)) div 2
    let paddedText = " ".repeat(textPadding) & buttonText & 
                    " ".repeat(buttonWidth - displayWidth(buttonText) - textPadding)
    
    buffer.print(buttonStartX + i * (buttonWidth + 2), startY + height - 2, 
                paddedText, Style(fg: ColorBlack, bg: ColorWhite))

# Draw settings page with proper bidirectional text support
proc drawSettings(buffer: var Buffer, lang: Language, currentDT: DateTime) =
  let headerStyle = Style(fg: ColorCyan, bg: ColorDefault, attrs: {AttrBold})
  let labelStyle = Style(fg: ColorYellow, bg: ColorDefault)
  let valueStyle = Style(fg: ColorWhite, bg: ColorDefault)
  let isRTL = lang in {Arabic, Hebrew}
  
  # Clear the content area
  let contentStartX = 25
  let contentWidth = buffer.width - contentStartX - 2
  
  for y in 5..<buffer.height-1:
    buffer.print(contentStartX, y, " ".repeat(contentWidth))
  
  # Draw header
  let header = translations[lang][Settings]
  if isRTL:
    # For RTL, right-align the header
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(header), 5, header, headerStyle)
  else:
    buffer.printAdvanced(contentStartX, 5, header, headerStyle)
  
  # Draw language setting
  let langLabel = translations[lang][Language]
  let langValue = $lang
  
  if isRTL:
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(langLabel), 7, langLabel, labelStyle)
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(langLabel) - displayWidth(langValue) - 2, 7, langValue, valueStyle)
  else:
    buffer.printAdvanced(contentStartX, 7, langLabel, labelStyle)
    buffer.printAdvanced(contentStartX + displayWidth(langLabel) + 2, 7, langValue, valueStyle)
  
  # Draw date/time setting
  let dtLabel = translations[lang][DateTime]
  let dateValue = formatDate(currentDT, lang)
  let timeValue = formatTime(currentDT, lang)
  
  if isRTL:
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(dtLabel), 9, dtLabel, labelStyle)
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(dtLabel) - displayWidth(dateValue) - 2, 9, dateValue, valueStyle)
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(dtLabel) - displayWidth(timeValue) - 2, 10, timeValue, valueStyle)
  else:
    buffer.printAdvanced(contentStartX, 9, dtLabel, labelStyle)
    buffer.printAdvanced(contentStartX + displayWidth(dtLabel) + 2, 9, dateValue, valueStyle)
    buffer.printAdvanced(contentStartX + displayWidth(dtLabel) + 2, 10, timeValue, valueStyle)
  
  # Draw text direction
  let dirLabel = "Text Direction"
  let dirValue = getTextDirection(lang)
  
  if isRTL:
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(dirLabel), 12, dirLabel, labelStyle)
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(dirLabel) - displayWidth(dirValue) - 2, 12, dirValue, valueStyle)
  else:
    buffer.printAdvanced(contentStartX, 12, dirLabel, labelStyle)
    buffer.printAdvanced(contentStartX + displayWidth(dirLabel) + 2, 12, dirValue, valueStyle)

# Draw a simple calendar with month and days
proc drawCalendar(buffer: var Buffer, lang: Language, currentDT: DateTime) =
  let headerStyle = Style(fg: ColorCyan, bg: ColorDefault, attrs: {AttrBold})
  let weekdayStyle = Style(fg: ColorYellow, bg: ColorDefault)
  let currentDayStyle = Style(fg: ColorBlack, bg: ColorWhite)
  let normalDayStyle = Style(fg: ColorWhite, bg: ColorDefault)
  let isRTL = lang in {Arabic, Hebrew}
  
  # Clear the content area
  let contentStartX = 25
  let contentWidth = buffer.width - contentStartX - 2
  
  for y in 5..<buffer.height-1:
    buffer.print(contentStartX, y, " ".repeat(contentWidth))
  
  # Draw header
  let header = translations[lang][Calendar]
  if isRTL:
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(header), 5, header, headerStyle)
  else:
    buffer.printAdvanced(contentStartX, 5, header, headerStyle)
  
  # Month and year
  let monthYear = formatDate(currentDT, lang)
  if isRTL:
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(monthYear), 7, monthYear, headerStyle)
  else:
    buffer.printAdvanced(contentStartX, 7, monthYear, headerStyle)
  
  # Weekday names - use English for simplicity
  let weekdays = if isRTL: ["Sat", "Fri", "Thu", "Wed", "Tue", "Mon", "Sun"] else: 
                          ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  
  for i, day in weekdays:
    let x = if isRTL: contentStartX + contentWidth - 4 - i*4 else: contentStartX + i*4
    buffer.print(x, 9, day, weekdayStyle)
  
  # Calculate first day of month
  let firstOfMonth = dateTime(currentDT.year, currentDT.month, 1, 0, 0, 0)
  let firstWeekday = firstOfMonth.weekday.int
  
  # Get days in month
  let daysInMonth = case currentDT.month
    of mFeb:
      if currentDT.year mod 4 == 0 and (currentDT.year mod 100 != 0 or currentDT.year mod 400 == 0): 29 else: 28
    of mApr, mJun, mSep, mNov:
      30
    else:
      31
  
  # Draw days
  var row = 0
  var col = if isRTL: 6 - firstWeekday else: firstWeekday
  
  for day in 1..daysInMonth:
    let x = if isRTL: contentStartX + contentWidth - 4 - col*4 else: contentStartX + col*4
    let style = if day == currentDT.monthday: currentDayStyle else: normalDayStyle
    buffer.print(x, 11 + row, fmt"{day:2}", style)
    
    col += 1
    if col >= 7:
      col = 0
      row += 1

# Draw a simple about dialog with program info
proc drawAbout(buffer: var Buffer, lang: Language) =
  let headerStyle = Style(fg: ColorCyan, bg: ColorDefault, attrs: {AttrBold})
  let textStyle = Style(fg: ColorWhite, bg: ColorDefault)
  let isRTL = lang in {Arabic, Hebrew}
  
  # Clear the content area
  let contentStartX = 25
  let contentWidth = buffer.width - contentStartX - 2
  
  for y in 5..<buffer.height-1:
    buffer.print(contentStartX, y, " ".repeat(contentWidth))
  
  # Draw header
  let header = translations[lang][About]
  if isRTL:
    buffer.printAdvanced(contentStartX + contentWidth - displayWidth(header), 5, header, headerStyle)
  else:
    buffer.printAdvanced(contentStartX, 5, header, headerStyle)
  
  # Program information
  let info = [
    "libterminal Internationalization Demo",
    "Version 1.0",
    "",
    "Demonstrates internationalization capabilities:",
    "- Multilingual support for 9 languages",
    "- Proper bidirectional text handling",
    "- Unicode-aware layout and alignment",
    "- Localized date and time formats",
    "",
    "© 2025 libterminal developers"
  ]
  
  for i, line in info:
    if isRTL and line.len > 0:
      buffer.printAdvanced(contentStartX + contentWidth - displayWidth(line), 7 + i, line, textStyle)
    else:
      buffer.printAdvanced(contentStartX, 7 + i, line, textStyle)

# Main application
proc main() =
  withTerminal:
    # Get initial size
    let (width, height) = raw.getTerminalSize()
    
    # Create a buffer
    var buffer = newBuffer(width, height)
    
    # Settings
    var currentLang = English
    var currentPage = "settings"
    var currentDT = now()
    var running = true
    
    # Menu items
    let menuItems = @[Settings, Calendar, About, Language, Help]
    var selectedMenuItem = 0
    
    # Main loop
    while running:
      # Clear screen
      buffer.clear()
      
      # Draw title
      let titleStyle = Style(fg: ColorMagenta, bg: ColorDefault, attrs: {AttrBold})
      let welcomeText = translations[currentLang][Welcome]
      
      # Title alignment depends on language direction
      if currentLang in {Arabic, Hebrew}:
        # Right-to-left language, right-align the title
        buffer.printAdvanced(width - displayWidth(welcomeText) - 2, 1, welcomeText, titleStyle)
      else:
        # Left-to-right language, left-align the title
        buffer.printAdvanced(2, 1, welcomeText, titleStyle)
      
      # Draw menu
      drawMenu(buffer, 2, 5, menuItems, currentLang, selectedMenuItem)
      
      # Draw content based on selected page
      case currentPage
      of "settings":
        drawSettings(buffer, currentLang, currentDT)
      of "calendar":
        drawCalendar(buffer, currentLang, currentDT)
      of "about":
        drawAbout(buffer, currentLang)
      of "language":
        # Draw language selection dialog
        drawDialog(buffer, translations[currentLang][Language],
                  "Select your preferred language:",
                  @[Yes, No, Cancel], currentLang)
      of "help":
        drawDialog(buffer, translations[currentLang][Help],
                  "This is a demonstration of libterminal's internationalization capabilities.\n" &
                  "Use arrow keys to navigate, Enter to select, and Q to quit.",
                  @[Yes], currentLang)
      else:
        discard
      
      # Draw footer
      let footerStyle = Style(fg: ColorWhite, bg: ColorBlue)
      let footerText = "Press Q to quit | Up/Down to navigate | Enter to select"
      buffer.print(0, height - 1, footerText & " ".repeat(width - displayWidth(footerText)), footerStyle)
      
      # Update display
      drawBuffer(buffer)
      
      # Process input
      let event = input.pollEvent()
      
      if event.kind == KeyPress:
        case event.key
        of KeyQ:
          running = false
        of KeyUp:
          selectedMenuItem = max(0, selectedMenuItem - 1)
        of KeyDown:
          selectedMenuItem = min(menuItems.high, selectedMenuItem + 1)
        of KeyReturn:
          case menuItems[selectedMenuItem]
          of Settings:
            currentPage = "settings"
          of Calendar:
            currentPage = "calendar"
          of About:
            currentPage = "about"
          of Language:
            # Cycle through languages when Language is selected
            let languages = [English, Japanese, Arabic, Russian, Spanish, Chinese, Korean, Hindi, Hebrew]
            let currentIdx = languages.find(currentLang)
            currentLang = languages[(currentIdx + 1) mod languages.len]
          of Help:
            currentPage = "help"
          else:
            discard
        of KeyL:
          # Shortcut to cycle through languages
          let languages = [English, Japanese, Arabic, Russian, Spanish, Chinese, Korean, Hindi, Hebrew]
          let currentIdx = languages.find(currentLang)
          currentLang = languages[(currentIdx + 1) mod languages.len]
        else:
          discard

when isMainModule:
  main()