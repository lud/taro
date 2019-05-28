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

  # Action is the subject so it's the first argument. match_tokens()
  # was implemented with the steps tokens as first argument, beware.

  def match_step(%__MODULE__{is_regex: true, regex: regex} = this, step, _),
    do: do_match_regex(step.text, regex)

  def match_step(%__MODULE__{is_regex: false, tokens: tokens} = this, step, step_tokens),
    do: match_tokens(step_tokens, tokens)

  def match_tokens(step, %Regex{} = re) do
    do_match_regex(step.text, re)
  end

  def match_tokens(tokens, action_tokens) do
    do_match(tokens, action_tokens)
  end

  defp do_match(step_tokens, action_tokens, acc \\ [])

  defp do_match([], [], acc),
    do: {:ok, :lists.reverse(acc)}

  # Match the same word
  defp do_match([{:word, word} | step_rest], [{:word, word} | action_rest], acc),
    do: do_match(step_rest, action_rest, acc)

  # Match a choice
  defp do_match([{:word, word} | step_rest], [{:word_choice, {word, _}} | action_rest], acc),
    do: do_match(step_rest, action_rest, acc)

  defp do_match([{:word, word} | step_rest], [{:word_choice, {_, word}} | action_rest], acc),
    do: do_match(step_rest, action_rest, acc)

  defp do_match([{:word, word} | step_rest], [{:word_choice, _} | action_rest], acc),
    do: {:error, :word_choice}

  # Match different words
  defp do_match([{:word, _wordA} | _], [{:word, _wordB} | _], _),
    do: {:error, :word}

  # Match a number as string
  defp do_match([{kind, {_, str}} | step_rest], [{:word, str} | action_rest], acc)
       when kind in [:integer, :float],
       do: do_match(step_rest, action_rest, acc)

  defp do_match([{kind, {_, _}} | step_rest], [{:word, _} | action_rest], acc)
       when kind in [:integer, :float],
       do: {:error, {kind, :word}}

  # Accept values

  defp do_match([{kind, {value, _}} | step_rest], [{:accept, _} | action_rest], acc)
       when kind in [:integer, :float],
       do: do_match(step_rest, action_rest, [value | acc])

  defp do_match([{:string, value} | step_rest], [{:accept, _} | action_rest], acc),
    do: do_match(step_rest, action_rest, [value | acc])

  # When encountering a single word, it is also capturing the value
  defp do_match([{:word, word} | step_rest], [{:accept, _} | action_rest], acc),
    do: do_match(step_rest, action_rest, [word | acc])

  # Match a regex. This is a special case, as we must rewrite the input

  defp do_match_regex(step_text, regex) do
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
