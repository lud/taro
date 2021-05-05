defmodule CoffeeMachine do
  defstruct coffees: 0, dollars: 0, served: 0, price: 0

  def new, do: %__MODULE__{}

  def set_coffees(machine, n),
    do: %__MODULE__{machine | coffees: n}

  def set_price(machine, n),
    do: %__MODULE__{machine | price: n}

  def insert_dollars(machine, n),
    do: %__MODULE__{machine | dollars: machine.dollars + n}

  def press_button(
        %__MODULE__{coffees: coffees, dollars: dollars, served: 0, price: price} = machine
      )
      when dollars >= price and coffees > 0 do
    dollars |> IO.inspect(label: "dollars")
    price |> IO.inspect(label: "price")
    %__MODULE__{machine | coffees: coffees - 1, dollars: dollars - 1, served: 1}
  end

  def press_button(%__MODULE__{dollars: d, price: p}) when d < p,
    do: raise("Not enough dollars were inserted")

  def press_button(%__MODULE__{served: 1}),
    do: raise("A coffee is already served")

  def press_button(%__MODULE__{dollars: 0}),
    do: raise("There is no dollars in the machine")

  def press_button(%__MODULE__{coffees: 0}),
    do: raise("There is no coffees in the machine")

  def take_coffee(%__MODULE__{served: 1} = machine),
    do: %__MODULE__{machine | served: 0}

  def take_coffee(%__MODULE__{served: 0}),
    do: raise("There is no coffee served")
end

defmodule Taro.Samples.Coffee do
  use Taro.Context

  @_Given ~r/there is a coffee (machine)/
  def given_there_is_coffee_machine(_context, "machine") do
    %{machine: CoffeeMachine.new()}
  end

  @_Given "there is at least one coffee in the machine"
  def given_there_is_at_least_one_coffee_in_the_machine(context) do
    given_there_are_coffees_left_in_the_machine(context, 1)
  end

  @_Given "there are :count coffees left in the machine"
  def given_there_are_coffees_left_in_the_machine(%{machine: machine}, count) do
    %{machine: CoffeeMachine.set_coffees(machine, count)}
  end

  @_Given "it is possible to buy it for one dollar"
  def given_it_is_possible_to_buy_it_for_one_dollar(context) do
    given_it_is_possible_to_buy_it_for_dollars(context, 1)
  end

  @_Given "it is possible to buy it for :price dollars"
  def given_it_is_possible_to_buy_it_for_dollars(%{machine: machine}, price)
      when is_integer(price) do
    %{machine: CoffeeMachine.set_price(machine, price)}
  end

  @_Given "I have deposited :dollars dollar"
  def and_i_have_deposited_dollar(%{machine: machine}, dollars) do
    machine = CoffeeMachine.insert_dollars(machine, dollars)

    IO.puts("Thanks for the money")
    %{machine: machine}
  end

  @_When "I press the coffee button"
  def when_i_press_the_coffee_button(%{machine: machine}) do
    try do
      %{machine: CoffeeMachine.press_button(machine)}
    rescue
      e ->
        IO.puts(e.message)
        %{}
    end
  end

  @_Then "I should be served a coffee"
  def then_i_should_be_served_a_coffee(%{machine: machine}) do
    machine = CoffeeMachine.take_coffee(machine)

    IO.puts("Enjoy your coffee :)")
    assert 0 = machine.served
    :ok
  end

  @_Then "I should not get my coffee"
  def then_i_should_not_get_my_coffee(%{machine: machine}) do
    err =
      assert_raise RuntimeError, fn ->
        machine = CoffeeMachine.take_coffee(machine)
      end

    IO.puts(err.message)
    :ok
  end
end
