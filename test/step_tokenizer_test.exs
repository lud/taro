defmodule StepTokenizerTest do
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
    assert_tokenized("héhéhé", word: "héhéhé")
    assert_tokenized("Hello World", word: "Hello", word: "World")
    assert_tokenized("I am a phrase", word: "I", word: "am", word: "a", word: "phrase")
    assert_tokenized("hé ho", word: "hé", word: "ho")

    # Quoted expressions (Strings)

    assert_tokenized("I am a 'quoted'", word: "I", word: "am", word: "a", string: "quoted")

    assert_tokenized("I am an 'escaped\\' quoted'",
      word: "I",
      word: "am",
      word: "an",
      string: "escaped' quoted"
    )

    # An escape sequence in a word results in a mere word
    assert_tokenized(~S(Strange number 1234\5),
      word: "Strange",
      word: "number",
      word: "1234\\5"
    )

    assert_raise(RuntimeError, fn ->
      tokenize("Unterminated 'string")
    end)

    assert_raise(RuntimeError, fn ->
      tokenize("'")
    end)

    assert_tokenized("I am a \"double quoted whith whitespace\"",
      word: "I",
      word: "am",
      word: "a",
      string: "double quoted whith whitespace"
    )

    # Integers
    assert_tokenized("1", integer: {1, "1"})
    assert_tokenized("a 1", word: "a", integer: {1, "1"})
    assert_tokenized("1 a", integer: {1, "1"}, word: "a")

    assert_tokenized("2 is more than 1",
      integer: {2, "2"},
      word: "is",
      word: "more",
      word: "than",
      integer: {1, "1"}
    )

    # Floats

    assert_tokenized("1.0", float: {1.0, "1.0"})
    assert_tokenized("123.0", float: {123.0, "123.0"})
    assert_tokenized("123.456", float: {123.456, "123.456"})
    assert_tokenized("1.0000000", float: {1.0, "1.0000000"})
    assert_tokenized("a 1.0", word: "a", float: {1.0, "1.0"})
    assert_tokenized("1.0 a", float: {1.0, "1.0"}, word: "a")
    assert_tokenized("0.0", float: {0.0, "0.0"})
    assert_tokenized("0.000000", float: {0.0, "0.000000"})
    assert_tokenized("0.0000001", float: {0.0000001, "0.0000001"})

    assert_tokenized("1.001 is more than 1 but less than 1.1",
      float: {1.001, "1.001"},
      word: "is",
      word: "more",
      word: "than",
      integer: {1, "1"},
      word: "but",
      word: "less",
      word: "than",
      float: {1.1, "1.1"}
    )

    # Strings with numbers

    assert_tokenized("number in 'string 123'",
      word: "number",
      word: "in",
      string: "string 123"
    )

    assert_tokenized("float in 'string 123.456'",
      word: "float",
      word: "in",
      string: "string 123.456"
    )
  end
end
