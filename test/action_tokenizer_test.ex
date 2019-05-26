defmodule HandlerTokenizerTest do
  use ExUnit.Case
  alias Taro.Tokenizer.ActionTokenizer
  import ActionTokenizer, only: [tokenize: 1]

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

    # Word choices
    assert_tokenized("Hello World/Universe", word: "Hello", word_choice: {"World", "Universe"})
    assert_raise RuntimeError, fn -> tokenize("a/b/") end
    assert_raise RuntimeError, fn -> tokenize("a/b/c") end
    assert_raise RuntimeError, fn -> tokenize("a/b/c/") end
    assert_raise RuntimeError, fn -> tokenize("a//") end
    assert_raise RuntimeError, fn -> tokenize("a//b") end

    # Values
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
