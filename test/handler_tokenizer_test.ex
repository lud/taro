defmodule HandlerTokenizerTest do
  use ExUnit.Case
  alias Taro.Tokenizer.HandlerTokenizer
  import HandlerTokenizer, only: [tokenize: 1]

  defp assert_tokenized(string, expected_tokens) do
    tokens = tokenize(string)
    assert tokens === expected_tokens
  end

  test "tokenize step defs" do
    # Words
    assert_tokenized("E", word: "E")
    assert_tokenized("EA", word: "EA")
    assert_tokenized("héhéhé", word: "héhéhé")
    assert_tokenized("Hello World", word: "Hello", word: "World")
    assert_tokenized("I am a phrase", word: "I", word: "am", word: "a", word: "phrase")
    assert_tokenized("hé ho", word: "hé", word: "ho")

    # full regex 
    assert_tokenized("/hello i am a regex/", regex: ~r/hello i am a regex/)
    assert_tokenized("/^hello i am a regex$/", regex: ~r/^hello i am a regex$/)

    assert_tokenized("/hello i am a \\/ slash/", regex: Regex.compile!("hello i am a \\/ slash"))

    assert_tokenized("/hello i contain a :colon/", regex: ~r/hello i contain a :colon/)

    assert_tokenized("/hello i contain a ([0-9]+) capture/",
      regex: ~r/hello i contain a ([0-9]+) capture/
    )

    assert_raise RuntimeError, fn -> tokenize("/unterminated regex") end
    assert_raise Regex.CompileError, fn -> tokenize("/bad ( regex/") end
  end
end
