defmodule Taro.SnippetFormatter do
  alias Taro.Tokenizer.StepTokenizer

  def format_snippet(step) do
    %{keyword: keyword, table_data: table_data, doc_string: doc_string, text: text} = step
    tokens = StepTokenizer.tokenize(text)

    """
    #{format_attribute(keyword, tokens)}
    #{format_function(keyword, tokens, doc_string, table_data)}
    """
  end

  defp format_attribute(keyword, tokens) do
    "@_#{keyword} \"#{format_tokens(tokens) |> Enum.join(" ")}\""
  end

  defp format_tokens(tokens, index \\ 0)

  defp format_tokens([{kind, {_, as_text}} | rest], index)
       when kind in [:string, :float, :integer],
       do: [":#{kind}_#{index}" | format_tokens(rest, index + 1)]

  defp format_tokens([{:word, word} | rest], index),
    do: ["#{word}" | format_tokens(rest, index)]

  defp format_tokens([], _),
    do: []

  defp format_function(keyword, tokens, doc_string, table_data) do
    fun_name = String.downcase(keyword) <> tokens_to_fun_name(tokens)

    args =
      tokens
      |> extract_step_values()

    args =
      case length(args) do
        0 -> ""
        _ -> ", " <> Enum.join(args, ", ")
      end

    extra_arg =
      case {doc_string, table_data} do
        {"", []} -> ""
        {_, []} -> ", doc_string"
        {"", _} -> ", table_data"
      end

    """
    def #{fun_name}(context#{args}#{extra_arg}) do
      raise Taro.Exception.Pending, message: "TODO implement this step"
    end
    """
  end

  defp tokens_to_fun_name([{kind, _} | rest])
       when kind in [:string, :float, :integer],
       do: tokens_to_fun_name(rest)

  defp tokens_to_fun_name([{:word, word} | rest]),
    do: "_" <> String.downcase(word) <> tokens_to_fun_name(rest)

  defp tokens_to_fun_name([_ | rest]),
    do: tokens_to_fun_name(rest)

  defp tokens_to_fun_name([]),
    do: ""

  defp extract_step_values(tokens, index \\ 0)

  defp extract_step_values([{kind, _} | rest], index)
       when kind in [:string, :float, :integer],
       do: ["#{kind}_#{index}" | extract_step_values(rest, index + 1)]

  defp extract_step_values([_ | rest], index),
    do: extract_step_values(rest, index)

  defp extract_step_values([], _),
    do: []
end
