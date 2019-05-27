defmodule HandlerTokenizerTest do
  use ExUnit.Case
  alias Taro.Tokenizer.ActionTokenizer
  import ActionTokenizer, only: [tokenize: 1]

  defp assert_tokenized(string, expected_tokens) do
    tokens = tokenize(string)
    assert tokens === expected_tokens
  end

  test "tokenize words" do
    assert_tokenized("E", word: "E")
    assert_tokenized("EA", word: "EA")
    assert_tokenized("héhéhé", word: "héhéhé")
    assert_tokenized("Hello World", word: "Hello", word: "World")
    assert_tokenized("I am a phrase", word: "I", word: "am", word: "a", word: "phrase")
    assert_tokenized("hé ho", word: "hé", word: "ho")
  end

  test "tokenize word choices" do
    # Word choices
    assert_tokenized("Hello World/Universe", word: "Hello", word_choice: {"World", "Universe"})
    assert_raise RuntimeError, fn -> tokenize("a/b/") end
    assert_raise RuntimeError, fn -> tokenize("a/b/c") end
    assert_raise RuntimeError, fn -> tokenize("a/b/c/") end
    assert_raise RuntimeError, fn -> tokenize("a//") end
    assert_raise RuntimeError, fn -> tokenize("a//b") end
  end

  test "tokenize accept values" do
    assert_tokenized("give me some :value",
      word: "give",
      word: "me",
      word: "some",
      accept: "value"
    )

    assert_tokenized("abc :trail", word: "abc", accept: "trail")
    assert_tokenized(":lead abc", accept: "lead", word: "abc")

    # Values names will be converted to snake case
    assert_tokenized(":CAPITAL", accept: "capital")
    assert_tokenized(":BIG_CONST", accept: "big_const")
    assert_tokenized(":PascalCase", accept: "pascal_case")
    assert_tokenized(":camelCase", accept: "camel_case")
    # We rely on Macro.underscore/1 so this following syntax will 
    # result in two underscores
    assert_tokenized(":Camel_Underscore", accept: "camel__underscore")
  end
end
