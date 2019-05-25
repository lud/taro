defmodule Taro.Tokenizer.StepTokenizer do
  @moduledoc """
  Tokenizer for the gherkin steps in a feature file. 

  We match on a limited set of characters:

  - (") and (') start a string expression
  - ([0-9]) start a number, if a dot is encountered we match a float
  """

  defguard is_num_char(digit) when digit >= ?0 and digit <= ?9
  defguard is_whitespace(char) when char == ?\s or char == ?\t

  def tokenize(string) when is_binary(string) do
    string
    |> String.to_charlist()
    |> to_tokens()
    |> cast_values()
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

  defp to_tokens([num | rest], tokens) when is_num_char(num) do
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

  defp parse_number_or_word(input, acc \\ [])

  # When finding digits, we try to parse an integer
  defp parse_number_or_word([num | rest], acc) when is_num_char(num),
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
  defp parse_float_or_word([num | rest], acc) when is_num_char(num),
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

  defp cast_values([{:word, word} | rest]),
    do: [{:word, to_string(word)} | cast_values(rest)]

  defp cast_values([{:string, string} | rest]),
    do: [{:string, to_string(string)} | cast_values(rest)]

  defp cast_values([{:integer, integer} | rest]),
    do: [{:integer, :erlang.list_to_integer(integer)} | cast_values(rest)]

  defp cast_values([{:float, float} | rest]),
    do: [{:float, :erlang.list_to_float(float)} | cast_values(rest)]

  defp cast_values([]),
    do: []
end
