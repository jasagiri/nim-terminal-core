Feature: Layout System
  As a library user
  I want to create complex layouts with components
  So that I can build structured terminal UIs

  Background:
    Given a terminal buffer is available
    And the layout system is initialized

  Scenario: Creating a basic horizontal split layout
    Given I create a horizontal layout with 2 sections
    When I set the left section to 30% width
    And I set the right section to 70% width
    Then the sections should be properly sized
    And the sections should not overlap

  Scenario: Creating a basic vertical split layout
    Given I create a vertical layout with 3 sections
    When I set the top section to 20% height
    And I set the middle section to 60% height
    And I set the bottom section to 20% height
    Then the sections should be properly sized vertically
    And the sections should not overlap

  Scenario: Creating a grid layout
    Given I create a 3x2 grid layout
    When I place components in each cell
    Then each component should occupy its designated cell
    And components should not overlap

  Scenario: Setting margins and padding
    Given I have a layout container
    When I set margins of 2 units on all sides
    And I set padding of 1 unit on all sides
    Then the inner content area should be reduced accordingly
    And spacing should be properly maintained

  Scenario: Nested layouts
    Given I have a main vertical layout
    When I add a horizontal layout inside one section
    And I add components to the nested layout
    Then the nested layout should work correctly
    And all components should be positioned properly

  Scenario: Dynamic resizing
    Given I have a layout with multiple sections
    When the terminal size changes
    Then all sections should resize proportionally
    And content should remain properly positioned