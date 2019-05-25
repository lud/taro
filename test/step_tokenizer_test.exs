defmodule TaroTest do
  use ExUnit.Case
  alias Taro.Tokenizer.StepTokenizer
  import StepTokenizer, only: [tokenize: 1]

  defp assert_tokenized(string, expected_tokens) do
    tokens = tokenize(string)
    assert tokens === expected_tokens
  end

  test "tokenize inputs" do
    # simple tokens
    assert_tokenized("E", word: "E")
    assert_tokenized("EA", word: "EA")
    assert_tokenized("Hello World", word: "Hello", word: "World")
    assert_tokenized("I am a phrase", word: "I", word: "am", word: "a", word: "phrase")

    # Quoted expressions
    assert_tokenized("I am a 'quoted'", word: "I", word: "am", word: "a", string: "quoted")

    assert_tokenized("I am a \"double quoted whith whitespace\"",
      word: "I",
      word: "am",
      word: "a",
      string: "double quoted whith whitespace"
    )

    # Integers
    assert_tokenized("1", integer: 1)
    assert_tokenized("a 1", word: "a", integer: 1)
    assert_tokenized("1 a", integer: 1, word: "a")

    assert_tokenized("2 is more than 1",
      integer: 2,
      word: "is",
      word: "more",
      word: "than",
      integer: 1
    )

    # Floats

    assert_tokenized("1.0", float: 1.0)
    assert_tokenized("1.0000000", float: 1.0)
    assert_tokenized("a 1.0", word: "a", float: 1.0)
    assert_tokenized("1.0 a", float: 1.0, word: "a")
    assert_tokenized("0.0", float: 0.0)
    assert_tokenized("0.000000", float: 0.0)
    assert_tokenized("0.0000001", float: 0.0000001)

    assert_tokenized("1.001 is more than 1 but less than 1.1",
      float: 1.001,
      word: "is",
      word: "more",
      word: "than",
      integer: 1,
      word: "but",
      word: "less",
      word: "than",
      float: 1.1
    )

    # tokens = tokenize("I am a phrase")
    # expected = [word: "I", word: "am", word: "a", word: "phrase"]
    # assert tokens === expected
    # # whitespace is ignored
    # assert tokenize("I am a string") === tokenize("I    am a \tstring")
    # # Empty string is supported
    # assert [] = tokenize("")
  end
end
