Feature: Widget System
  As a library user
  I want to create interactive terminal UI components
  So that I can build sophisticated terminal applications

  Background:
    Given the terminal is in raw mode
    And the layout system is initialized

  Scenario: Creating a basic widget hierarchy
    Given I create a root container widget
    When I add child widgets to the container
    Then each child should be properly positioned
    And all widgets should receive render calls

  Scenario: Styling widgets
    Given I have various widget types
    When I apply styles to each widget
    Then each widget should render with the correct visual style
    And style inheritance should work properly

  Scenario: Handling widget focus
    Given I have multiple interactive widgets
    When I navigate through them using Tab key
    Then focus should move between widgets in the correct order
    And the focused widget should have a different visual appearance

  Scenario: Widget events and callbacks
    Given I have widgets that produce events
    When I register event handlers for these widgets
    And I trigger events on these widgets
    Then the correct event handlers should be called
    And the widget state should be updated appropriately

  Scenario: Interactive button widget
    Given I create a button with text "Click Me"
    When I click on the button
    Then the button should visually indicate being pressed
    And the button's onClick handler should be called

  Scenario: Text input widget
    Given I create a text input field
    When I type characters into the field
    Then the text should be displayed in the field
    And I should be able to edit the text using arrow keys and delete

  Scenario: Checkbox widget
    Given I create a checkbox widget
    When I toggle the checkbox
    Then its checked state should change
    And it should display a different visual indicator based on state

  Scenario: List widget
    Given I create a list widget with multiple items
    When I navigate through the list
    Then the selected item should be highlighted
    And I should be able to select an item

  Scenario: Widget state changes
    Given widgets with mutable state
    When I programmatically change widget state
    Then the widget should update its visual representation
    And any registered state change handlers should be called

  Scenario: Widget measuring and layout
    Given widgets with different size requirements
    When the container is resized
    Then widgets should adjust their size appropriately
    And maintain their relative positioning

  Scenario: Event propagation
    Given a nested hierarchy of widgets
    When an event occurs on a deeply nested widget
    Then the event should propagate up the hierarchy
    And parent widgets should have the option to handle or ignore it

  Scenario: Shortcut key handling
    Given widgets with registered shortcut keys
    When I press a shortcut key combination
    Then the appropriate widget action should be triggered
    Even if the widget doesn't have focus