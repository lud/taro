defmodule Taro.Tokenizer.ActionTokenizer do
  @moduledoc """
  Tokenizer for the step attributes to mach on step tokens

  We match on a limited set of characters:

  - (/) matches a regex until (/) is encountered again
  - (:) matches a value acceptor until whitespace/end
  - (/) inside a word, followed by a word, matches a word choice
  """

  defguard is_whitespace(char) when char == ?\s or char == ?\t
  defguard is_digit(digit) when digit >= ?0 and digit <= ?9

  defguard is_ascii_char(char)
           when (char >= ?a and char <= ?z) or
                  (char >= ?A and char <= ?Z) or
                  char === ?_

  defguard is_number

  def tokenize(string) when is_binary(string) do
    string
    |> String.to_charlist()
    |> to_tokens()
    |> cast_tokens()
  end

  defp to_tokens(input, acc \\ [])

  defp to_tokens([?/ | rest], tokens) do
    {:regex, regex, rest} = parse_regex(rest)
    to_tokens(rest, [{:regex, regex} | tokens])
  end

  defp to_tokens([?: | rest], tokens) do
    {:accept, name, rest} = parse_accept(rest)
    to_tokens(rest, [{:accept, name} | tokens])
  end

  defp to_tokens([ws | rest], tokens) when is_whitespace(ws),
    do: to_tokens(rest, tokens)

  defp to_tokens([char | rest], tokens) do
    case parse_word([char | rest]) do
      {:word, word, rest} ->
        to_tokens(rest, [{:word, word} | tokens])

      {:word_choice, words_ab, rest} ->
        to_tokens(rest, [{:word_choice, words_ab} | tokens])
    end
  end

  defp to_tokens([], tokens),
    do: reverse(tokens)

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

  # Encountering a slash, switch to a word_choice
  defp parse_word([?/, char | rest], acc) when not is_whitespace(char),
    do: parse_word_choice([char | rest], reverse(acc))

  # Anything else is in the word
  defp parse_word([char | rest], acc),
    do: parse_word(rest, [char | acc])

  # Parsing word choices is like parsing a word but we do not allow
  # a slash and revert to a mere word if a slash is encountered.
  # Parse word will send us there only if there is non-whitespace
  # input after the slash. So we can match whitespace and [] because
  # we know that we will have consumed a non-empty character before.

  defp parse_word_choice(input, word_a, acc \\ [])

  defp parse_word_choice([ws | rest], word_a, acc) when is_whitespace(ws),
    do: {:word_choice, {word_a, reverse(acc)}, rest}

  defp parse_word_choice([], word_a, acc),
    do: {:word_choice, {word_a, reverse(acc)}, []}

  defp parse_word_choice([?/ | rest], word_a, acc),
    do:
      raise("""
      Unexpected slash (/) after #{word_a}/#{reverse(acc)}
      """)

  defp parse_word_choice([char | rest], word_a, acc),
    do: parse_word_choice(rest, word_a, [char | acc])

  # Parsing arguments names. The names will not be used to call the
  # context functions, but will be useful to generate snippets.
  # So we require valid variable names. More precisely, we accept only
  # letters and underscore in the first position, then also digits.
  # We will use Macro.underscore/1 to transform the name into a valid
  # variable name, and left-pad reserved words
  defp parse_accept(input, acc \\ [])

  defp parse_accept([char | rest], acc) when is_ascii_char(char),
    do: parse_accept_tail(rest, [char | acc])

  defp parse_accept_tail([char | rest], acc) when is_ascii_char(char) or is_digit(char),
    do: parse_accept_tail(rest, [char | acc])

  defp parse_accept_tail([ws | rest], acc) when is_whitespace(ws),
    do: {:accept, reverse(acc), rest}

  defp parse_accept_tail([], acc),
    do: {:accept, reverse(acc), []}

  defp parse_accept_tail([char | rest], acc),
    do:
      raise("""
      Only ascii characters are allowed in arguments names :
      [a-zA-Z_][0-9a-zA-Z_]*
      """)

  defdelegate reverse(val), to: :lists

  defp cast_tokens([value | rest]),
    do: [cast_token(value) | cast_tokens(rest)]

  defp cast_tokens([]),
    do: []

  defp cast_token({:word, word}),
    do: {:word, to_string(word)}

  defp cast_token({:word_choice, {word_a, word_b}}),
    do: {:word_choice, {to_string(word_a), to_string(word_b)}}

  defp cast_token({:regex, regex}),
    do: {:regex, Regex.compile!(to_string(regex))}

  defp cast_token({:regex, regex}),
    do: {:regex, Regex.compile!(to_string(regex))}

  defp cast_token({:accept, name}),
    do: {:accept, Macro.underscore(to_string(name))}
end
