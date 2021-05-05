Feature: Serve coffee
  In order to earn money
  Customers should be able to
  buy coffee at all times

  Background:
    Given there is a coffee machine

  Scenario: Buy last coffee
    Given there is at least one coffee in the machine
      And it is possible to buy it for one dollar
      And there are 1 coffees left in the machine
      And I have deposited 1 dollar
    When I press the coffee button
    Then I should be served a coffee

  Scenario: Try to underpay
    Given there is at least one coffee in the machine
      And it is possible to buy it for 2 dollars
      And there are 1 coffees left in the machine
      And I have deposited 1 dollar
    When I press the coffee button
    Then I should not get my coffee
