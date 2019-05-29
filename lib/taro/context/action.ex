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

  def set_args(%__MODULE__{} = this, args) when is_list(args),
    do: %__MODULE__{this | args: args}

  # match_step/2 is for test purpose, step tokens should be computed 
  # only once, not for every action
  def match_step(%__MODULE__{} = this, step) do
    step_tokens = StepTokenizer.tokenize(step.text)
    match_step(this, step, step_tokens)
  end

  def match_step(%__MODULE__{is_regex: true, regex: regex} = this, step, _step_tokens),
    do: do_match_regex(regex, step.text)

  def match_step(%__MODULE__{is_regex: false, tokens: tokens} = this, _step, step_tokens),
    do: match_tokens(tokens, step_tokens)

  def match_tokens(tokens, step_tokens) do
    do_match(tokens, step_tokens)
  end

  defp do_match(action_tokens, step_tokens, acc \\ [])

  defp do_match([], [], acc),
    do: {:ok, :lists.reverse(acc)}

  # Match the same word
  defp do_match([{:word, word} | action_rest], [{:word, word} | step_rest], acc),
    do: do_match(action_rest, step_rest, acc)

  # Match a choice
  defp do_match([{:word_choice, {word, _}} | action_rest], [{:word, word} | step_rest], acc),
    do: do_match(action_rest, step_rest, acc)

  defp do_match([{:word_choice, {_, word}} | action_rest], [{:word, word} | step_rest], acc),
    do: do_match(action_rest, step_rest, acc)

  defp do_match([{:word_choice, _} | action_rest], [{:word, word} | step_rest], acc),
    do: {:error, :word_choice}

  # Match different words
  defp do_match([{:word, _wordB} | _], [{:word, _wordA} | _], _),
    do: {:error, :word}

  # Match a number as string
  defp do_match([{:word, str} | action_rest], [{kind, {_, str}} | step_rest], acc)
       when kind in [:integer, :float],
       do: do_match(action_rest, step_rest, acc)

  defp do_match([{:word, _} | action_rest], [{kind, {_, _}} | step_rest], acc)
       when kind in [:integer, :float],
       do: {:error, {kind, :word}}

  # Accept values

  defp do_match([{:accept, _} | action_rest], [{kind, {value, _}} | step_rest], acc)
       when kind in [:integer, :float],
       do: do_match(action_rest, step_rest, [value | acc])

  defp do_match([{:accept, _} | action_rest], [{:string, value} | step_rest], acc),
    do: do_match(action_rest, step_rest, [value | acc])

  # When encountering a single word, it is also capturing the value
  defp do_match([{:accept, _} | action_rest], [{:word, word} | step_rest], acc),
    do: do_match(action_rest, step_rest, [word | acc])

  # Match a regex. This is a special case, as we must rewrite the input

  defp do_match_regex(regex, step_text) do
    case Regex.run(regex, step_text, capture: :all_but_first) do
      nil -> {:error, :regex}
      captures -> {:ok, captures}
    end
  end

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
