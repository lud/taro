defmodule CoffeeMachine do
  defstruct coffees: 0, dollars: 0, served: 0

  def new, do: %__MODULE__{}

  def to_int(n) do
    {int, ""} = Integer.parse(n)
    int
  end

  def set_coffees(machine, n),
    do: %__MODULE__{machine | coffees: to_int(n)}

  def insert_dollars(machine, n),
    do: %__MODULE__{machine | dollars: machine.dollars + to_int(n)}

  def press_button(%__MODULE__{coffees: coffees, dollars: dollars, served: 0} = machine)
      when dollars > 0 and coffees > 0 do
    %__MODULE__{machine | coffees: coffees - 1, dollars: dollars - 1, served: 1}
  end

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

  @step "there is a coffee machine"
  def there_is_a_coffee_machine(context) do
    merge(%{machine: CoffeeMachine.new()})
  end

  @step "there are :count coffees left in the machine"
  def there_are_n_coffees_left_in_the_machine(context, n) do
    machine =
      context
      |> get_context(:machine)
      |> CoffeeMachine.set_coffees(n)

    merge(%{machine: machine})
  end

  @step "I have deposited (\\d+) dollars?"
  def i_have_deposited_n_dollars(context, dollars) do
    machine =
      context
      |> get_context(:machine)
      |> CoffeeMachine.insert_dollars(dollars)

    merge(%{machine: machine})
  end

  @step "I press the coffee button"
  def i_press_the_coffee_button(context) do
    machine =
      context
      |> get_context(:machine)
      |> CoffeeMachine.press_button()

    merge(%{machine: machine})
  end

  @step "I should be served a coffee"
  def i_should_be_served_a_coffee(context) do
    machine =
      context
      |> get_context(:machine)
      |> CoffeeMachine.take_coffee()

    assert 0 = machine.served
    :ok
  end
end
