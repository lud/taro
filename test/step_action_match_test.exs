defmodule StepActionMatchTest do
  use ExUnit.Case
  alias Taro.Tokenizer.StepTokenizer
  alias Taro.Tokenizer.ActionTokenizer

  def match_tokens(step, action_tokens) do
    case action_tokens do
      # A single regex
      [{:regex, _} = re] -> do_match_regex(step.source, re)
      tokens -> do_match(step.tokens, tokens)
    end
  end

  def do_match(step_tokens, action_tokens, acc \\ [])

  def do_match([], [], acc),
    do: {:ok, :lists.reverse(acc)}

  # Match the same word
  def do_match([{:word, word} | step_rest], [{:word, word} | action_rest], acc),
    do: do_match(step_rest, action_rest, acc)

  # Match a choice
  def do_match([{:word, word} | step_rest], [{:word_choice, {word, _}} | action_rest], acc),
    do: do_match(step_rest, action_rest, acc)

  def do_match([{:word, word} | step_rest], [{:word_choice, {_, word}} | action_rest], acc),
    do: do_match(step_rest, action_rest, acc)

  def do_match([{:word, word} | step_rest], [{:word_choice, _} | action_rest], acc),
    do: {:error, :word_choice}

  # Match different words
  def do_match([{:word, _wordA} | _], [{:word, _wordB} | _], _),
    do: {:error, :word}

  # Match a number as string
  def do_match([{kind, {_, str}} | step_rest], [{:word, str} | action_rest], acc)
      when kind in [:integer, :float],
      do: do_match(step_rest, action_rest, acc)

  def do_match([{kind, {_, _}} | step_rest], [{:word, _} | action_rest], acc)
      when kind in [:integer, :float],
      do: {:error, {kind, :word}}

  # Accept values

  def do_match([{kind, {value, _}} | step_rest], [{:accept, _} | action_rest], acc)
      when kind in [:integer, :float],
      do: do_match(step_rest, action_rest, [value | acc])

  def do_match([{:string, value} | step_rest], [{:accept, _} | action_rest], acc),
    do: do_match(step_rest, action_rest, [value | acc])

  # Match a regex. This is a special case, as we must rewrite the input

  def do_match_regex(step_source, {:regex, regex}) do
    case Regex.run(regex, step_source, capture: :all_but_first) do
      nil -> {:error, :regex}
      captures -> {:ok, captures}
    end
  end

  ## ABOVE IS IMPLEMENTATION WORKSPACE

  def assert_match(step_def, action_def, expected_args \\ []) do
    step_tokens = StepTokenizer.tokenize(step_def)
    action_tokens = ActionTokenizer.tokenize(action_def)
    step = %{source: step_def, tokens: step_tokens}
    assert {:ok, action_args} = match_tokens(step, action_tokens)
    # IO.inspect({action_def, action_args}, pretty: true)
    assert expected_args === action_args
  end

  def assert_not_match(step_def, action_def, reason) do
    step_tokens = StepTokenizer.tokenize(step_def)
    action_tokens = ActionTokenizer.tokenize(action_def)
    step = %{source: step_def, tokens: step_tokens}

    assert {:error, ^reason} = match_tokens(step, action_tokens)
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
    assert_match("the price is 20", "/the price is (\\d+)/", ["20"])
  end
end
