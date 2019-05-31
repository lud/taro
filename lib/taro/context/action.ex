defmodule Taro.Context.Action do
  alias Taro.Tokenizer.ActionTokenizer
  alias Taro.Tokenizer.StepTokenizer
  alias Gherkin.Elements.Step

  defstruct accept_count: nil,
            args: [],
            fun: nil,
            is_regex: false,
            mod: nil,
            regex: nil,
            source: nil,
            tokens: nil,
            print_tokens: nil,
            kind: nil

  defguard is_kind(kind) when kind in [:_Given, :_When, :_Then]

  def from_source({kind, %Regex{} = regex}, mod, fun) when is_kind(kind) do
    %__MODULE__{source: regex, regex: regex, mod: mod, fun: fun, is_regex: true}
  end

  def from_source({kind, source}, mod, fun) when is_kind(kind) do
    tokens = ActionTokenizer.tokenize(source)

    %__MODULE__{
      source: source,
      tokens: tokens,
      mod: mod,
      fun: fun,
      accept_count: count_accepts(tokens)
    }
  end

  # match_step/2 is for test purpose, step tokens should be computed 
  # only once, not for every action
  def match_step(%__MODULE__{} = this, step) do
    step_tokens = StepTokenizer.tokenize(step.text)
    match_step(this, step, step_tokens)
  end

  @doc """
  Returns the result of the match : a list of tokens with either 
  {:text, text} or {:arg, arg} in order to ease printing out args
  in the console.

  See extract_args to get only the args values
  """
  def match_step(%__MODULE__{is_regex: true, regex: regex} = this, step, _step_tokens) do
    do_match_regex(regex, step.text)
    |> handle_matched(this)
  end

  def match_step(%__MODULE__{is_regex: false, tokens: tokens} = this, _step, step_tokens) do
    match_tokens(tokens, step_tokens)
    |> handle_matched(this)
  end

  defp handle_matched({:ok, match_result}, this) do
    args = extract_args(match_result)
    {:ok, %__MODULE__{this | print_tokens: match_result, args: args}}
  end

  defp handle_matched(error, _),
    do: error

  defp extract_args([{:text, _} | match_result]),
    do: extract_args(match_result)

  defp extract_args([{:arg, value} | match_result]),
    do: [value | extract_args(match_result)]

  defp extract_args([]),
    do: []

  def match_tokens(tokens, step_tokens) do
    do_match(tokens, step_tokens)
  end

  defp do_match(action_tokens, step_tokens, acc \\ [])

  defp do_match([], [], acc),
    do: {:ok, :lists.reverse(acc)}

  # Match the same word
  defp do_match([{:word, word} | action_rest], [{:word, word} | step_rest], acc),
    do: do_match(action_rest, step_rest, [{:text, word} | acc])

  # Match a choice
  defp do_match([{:word_choice, {word, _}} | action_rest], [{:word, word} | step_rest], acc),
    do: do_match(action_rest, step_rest, [{:text, word} | acc])

  defp do_match([{:word_choice, {_, word}} | action_rest], [{:word, word} | step_rest], acc),
    do: do_match(action_rest, step_rest, [{:text, word} | acc])

  defp do_match([{:word_choice, _} | action_rest], [{:word, word} | step_rest], acc),
    do: {:error, :word_choice}

  # Match different words
  defp do_match([{:word, _wordB} | _], [{:word, _wordA} | _], _),
    do: {:error, :word}

  # Match a number as a word
  defp do_match([{:word, str} | action_rest], [{kind, {_, str}} | step_rest], acc)
       when kind in [:integer, :float],
       do: do_match(action_rest, step_rest, [{:text, str} | acc])

  defp do_match([{:word, _} | action_rest], [{kind, {_, _}} | step_rest], acc)
       when kind in [:integer, :float],
       do: {:error, {kind, :word}}

  # Accept values

  defp do_match([{:accept, _} | action_rest], [{kind, {value, _}} | step_rest], acc)
       when kind in [:integer, :float],
       do: do_match(action_rest, step_rest, [{:arg, value} | acc])

  defp do_match([{:accept, _} | action_rest], [{:string, value} | step_rest], acc),
    do: do_match(action_rest, step_rest, [{:arg, value} | acc])

  # When encountering a single word, it is also capturing the value
  defp do_match([{:accept, _} | action_rest], [{:word, word} | step_rest], acc),
    do: do_match(action_rest, step_rest, [{:arg, word} | acc])

  # Match a regex. This is a special case, as we must rewrite the input

  defp do_match_regex(regex, step_text) do
    IO.puts("step text #{step_text}")

    case Regex.run(regex, step_text, capture: :all_but_first, return: :index) do
      nil ->
        {:error, :regex}

      capture_indexes ->
        IO.puts("step text 2 #{step_text}")
        match_result = regex_indexes_to_match_result(capture_indexes, step_text)
        {:ok, match_result}
    end
  end

  defp regex_indexes_to_match_result(capture_indexes, step_text) do
    IO.puts("overlap ?  #{regex_indexes_overlap?(capture_indexes)}")

    if regex_indexes_overlap?(capture_indexes) do
      # @todo enhance printout
      # arg will be a single list
      captures = capture_indexes |> Enum.map(fn {i, l} -> binary_part(step_text, i, l) end)

      [{:text, step_text}, {:arg, captures}]
    else
      regex_indexes_to_match_result(capture_indexes, step_text, 0)
    end
  end

  defp regex_indexes_to_match_result([{i_start, c_length} | rest], step_text, pos)
       when pos < i_start do
    text =
      binary_part(step_text, pos, i_start - pos)
      |> String.trim()

    next = [
      {:text, text}
      | regex_indexes_to_match_result([{i_start, c_length} | rest], step_text, i_start)
    ]
  end

  defp regex_indexes_to_match_result([{i_start, c_length} | rest], step_text, pos)
       when pos === i_start do
    value = binary_part(step_text, i_start, c_length)

    next = [
      {:arg, value}
      | regex_indexes_to_match_result(rest, step_text, i_start + c_length)
    ]
  end

  defp regex_indexes_to_match_result([], _step_text, pos),
    do: []

  defp regex_indexes_overlap?([{i_start, i_length}, {i_start_next, _} | rest])
       when i_start + i_length > i_start_next,
       do: true

  defp regex_indexes_overlap?([_ | rest]),
    do: regex_indexes_overlap?(rest)

  defp regex_indexes_overlap?([_ | []]),
    do: false

  defp regex_indexes_overlap?([]),
    do: false

  def format(%__MODULE__{is_regex: true, regex: regex, kind: kind}),
    do: "@#{kind} #{regex}"

  def format(%__MODULE__{is_regex: false, source: source, kind: kind}),
    do: "@#{kind} \"#{source}\""

  defp count_accepts(tokens),
    do: count_accepts(tokens, 0)

  defp count_accepts([{:accept, _} | rest], count),
    do: count_accepts(rest, count + 1)

  defp count_accepts([_ | rest], count),
    do: count_accepts(rest, count)

  defp count_accepts([], count),
    do: count
end
