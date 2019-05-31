defmodule StepActionMatchTest do
  use ExUnit.Case
  alias Taro.Tokenizer.StepTokenizer
  alias Taro.Tokenizer.ActionTokenizer
  alias Taro.Context.Action

  defp prepare_match(step_def, action_def) do
    step = %{text: step_def}
    action = Action.from_source({:_Given, action_def}, nil, nil)
    {step, action}
  end

  def assert_match(step_def, action_def, expected_args \\ []) do
    {step, action} = prepare_match(step_def, action_def)
    assert {:ok, action} = Action.match_step(action, step)
    assert expected_args === action.args
  end

  def assert_not_match(step_def, action_def, reason) do
    {step, action} = prepare_match(step_def, action_def)
    assert {:error, ^reason} = Action.match_step(action, step)
  end

  test "match words" do
    assert_match("i am a phrase", "i am a phrase")
    assert_match("the   whitespace    is weird   ", "the  whitespace is    weird   ")

    assert_not_match("I am a phrase", "I am a sentence", :word)
  end

  test "match word choices" do
    assert_match("start", "start/stop")
    assert_match("stop", "start/stop")

    assert_match("start the string", "start/debut the string")
    assert_match("debut the string", "start/debut the string")
    assert_match("at the end", "at the end/fin")
    assert_match("at the fin", "at the end/fin")
    assert_match("solo", "solo/single")
    assert_match("single", "solo/single")
    assert_match("i am a phrase", "i am a phrase/sentence")
    assert_match("i am a sentence", "i am a phrase/sentence")
    assert_not_match("i am a proverb", "i am a phrase/sentence", :word_choice)
  end

  test "match numbers as strings" do
    assert_match("this is 2019", "this is 2019")
    assert_match("random is 0.345", "random is 0.345")
    assert_not_match("the 100", "the hundred", {:integer, :word})
    assert_not_match("rnd 10.001", "rnd 10", {:float, :word})
  end

  test "accept values" do
    assert_match("the name is Joe", "the name is :name", ["Joe"])
    assert_match("the price is 20", "the price is :price", [20])
    assert_match("the price is 1.5", "the price is :price", [1.5])

    assert_match(
      "the price is 1.5 and the name is 'some stuff'",
      "the price is :price and the name is :name",
      [
        1.5,
        "some stuff"
      ]
    )

    assert_match("the name is 'The 7 Samurai'", "the name is :name", ["The 7 Samurai"])
  end

  test "regular expressions match" do
    # assert_match("the price is 20", ~r/the price is (\d+)/, ["20"])
    # assert_not_match("the price is 20", ~r/the day is (\d+)/, :regex)
    # captures overlap
    # assert_match("the day is Mon 20", ~r/the day is ([a-zA-Z]+ (\d+))/, [["Mon 20", "20"]])
  end
end
