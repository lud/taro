defmodule Taro.Context.Action do
  alias Taro.Tokenizer.ActionTokenizer
  alias Gherkin.Elements.Step

  defstruct kind: nil,
            source: nil,
            tokens: nil,
            regex: nil,
            mod: nil,
            fun: nil,
            is_regex: false,
            accept_count: nil

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
