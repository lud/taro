defmodule Taro.Tokenizer.HandlerTokenizer do
  @moduledoc """
  Tokenizer for the step attributes to mach on step tokens

  We match on a limited set of characters:

  - (/) matches a regex until (/) is encountered again
  - (:) matches a value acceptor until whitespace/end
  - (/) inside a word, followed by a word, matches a word choice
  """

  defguard is_whitespace(char) when char == ?\s or char == ?\t

  def tokenize(string) when is_binary(string) do
    string
    |> String.to_charlist()
    |> to_tokens()
    |> cast_values()
  end

  defp to_tokens(input, acc \\ [])

  defp to_tokens([?/ | rest], tokens) do
    {:regex, regex, rest} = parse_regex(rest, [])
    to_tokens(rest, [{:regex, regex} | tokens])
  end

  defp to_tokens([], tokens),
    do: reverse(tokens)

  defp to_tokens([ws | rest], tokens) when is_whitespace(ws),
    do: to_tokens(rest, tokens)

  defp to_tokens([char | rest], tokens) do
    {:word, word, rest} = parse_word([char | rest])
    to_tokens(rest, [{:word, word} | tokens])
  end

  defp parse_regex(input, acc \\ [])
  # When encountering a backslash, we keep it in the regex 
  defp parse_regex([?\\, char | rest], acc),
    do: parse_regex(rest, [char, ?\\ | acc])

  defp parse_regex([?/ | rest], acc) do
    {:regex, reverse(acc), rest}
  end

  defp parse_regex([char | rest], acc),
    do: parse_regex(rest, [char | acc])

  defp parse_regex([], acc),
    do:
      raise("""
      Unterminated regular expression starting with #{acc |> reverse |> to_string()}
      """)

  defp parse_word(input, acc \\ [])

  # Matching a word, we must stop at whitespace …
  defp parse_word([ws | rest], acc) when is_whitespace(ws),
    do: {:word, reverse(acc), rest}

  # … or stop at input end
  defp parse_word([], acc),
    do: {:word, reverse(acc), []}

  # Anything else is in the word
  defp parse_word([char | rest], acc),
    do: parse_word(rest, [char | acc])

  defdelegate reverse(val), to: :lists

  defp cast_values([{:word, word} | rest]),
    do: [{:word, to_string(word)} | cast_values(rest)]

  defp cast_values([{:regex, regex} | rest]),
    do: [{:regex, Regex.compile!(to_string(regex))} | cast_values(rest)]

  defp cast_values([]),
    do: []
end
