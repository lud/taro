defmodule Taro.Tokenizer.StepTokenizer do
  @moduledoc """
  Tokenizer for the gherkin steps in a feature file. 

  We match on a limited set of characters:

  - (") and (') start a string expression
  - ([0-9]) start a number, if a dot is encountered we match a float
  """

  defguard is_digit(digit) when digit >= ?0 and digit <= ?9
  defguard is_whitespace(char) when char == ?\s or char == ?\t

  def tokenize(string) when is_binary(string) do
    string
    |> String.to_charlist()
    |> to_tokens()
    |> cast_tokens()
  end

  defp to_tokens(input, acc \\ [])

  defp to_tokens([?" | rest], tokens) do
    {string, rest} = parse_string_expr(rest, [], ?")
    to_tokens(rest, [{:string, string} | tokens])
  end

  defp to_tokens([?' | rest], tokens) do
    {string, rest} = parse_string_expr(rest, [], ?')
    to_tokens(rest, [{:string, string} | tokens])
  end

  defp to_tokens([num | rest], tokens) when is_digit(num) do
    {kind, value, rest} = parse_number_or_word([num | rest])
    to_tokens(rest, [{kind, value} | tokens])
  end

  defp to_tokens([], tokens),
    do: reverse(tokens)

  defp to_tokens([ws | rest], tokens) when is_whitespace(ws),
    do: to_tokens(rest, tokens)

  defp to_tokens([char | rest], tokens) do
    {:word, word, rest} = parse_word([char | rest])
    to_tokens(rest, [{:word, word} | tokens])
  end

  defp parse_string_expr([close_char | rest], acc, close_char),
    do: {reverse(acc), rest}

  defp parse_string_expr([?\\, char | rest], acc, close_char),
    do: parse_string_expr(rest, [char | acc], close_char)

  defp parse_string_expr([char | rest], acc, close_char),
    do: parse_string_expr(rest, [char | acc], close_char)

  defp parse_string_expr([], acc, close_char),
    do:
      raise("""
      Unterminated string expression started as #{<<close_char, to_string(reverse(acc))::binary>>}
      """)

  defp parse_number_or_word(input, acc \\ [])

  # When finding digits, we try to parse an integer
  defp parse_number_or_word([num | rest], acc) when is_digit(num),
    do: parse_number_or_word(rest, [num | acc])

  # If we find a dot, we switch to a float
  defp parse_number_or_word([?. | rest], acc),
    do: parse_float_or_word(rest, [?. | acc])

  # If we find whitespace, we return the integer, space is discarded
  defp parse_number_or_word([ws | rest], acc) when is_whitespace(ws),
    do: {:integer, reverse(acc), rest}

  # If no more input, we return the integer
  defp parse_number_or_word([], acc),
    do: {:integer, reverse(acc), []}

  # If anything else, we try to parse a word
  defp parse_number_or_word(rest, acc),
    do: parse_word(rest, acc)

  # We match digits and continue to build a float
  defp parse_float_or_word([num | rest], acc) when is_digit(num),
    do: parse_float_or_word(rest, [num | acc])

  # If we find whitespace, we return the float, space is discarded
  defp parse_float_or_word([ws | rest], acc) when is_whitespace(ws),
    do: {:float, reverse(acc), rest}

  # If no more input, we return the float
  defp parse_float_or_word([], acc),
    do: {:float, reverse(acc), []}

  # If anything else, we switch to a mere word
  defp parse_float_or_word(rest, acc),
    do: parse_word(rest, acc)

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

  defp cast_tokens([value | rest]),
    do: [cast_token(value) | cast_tokens(rest)]

  defp cast_tokens([]),
    do: []

  defp cast_token({:word, word}),
    do: {:word, to_string(word)}

  defp cast_token({:string, string}),
    do: {:string, to_string(string)}

  defp cast_token({:integer, integer}),
    do: {:integer, {:erlang.list_to_integer(integer), to_string(integer)}}

  defp cast_token({:float, float}),
    do: {:float, {:erlang.list_to_float(float), to_string(float)}}
end
