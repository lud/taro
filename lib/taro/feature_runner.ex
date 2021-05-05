defmodule Taro.FeatureRunner do
  import Ark.Wok
  alias Gherkin.Elements.Step
  alias Taro.Context
  alias Taro.Context.Action
  alias Taro.Context.Compiler
  alias Taro.SnippetFormatter
  alias Taro.Tokenizer.StepTokenizer

  @indent_feat__ "  "
  @indent_feat_t "    "
  @indent_scen__ "    "
  @indent_scen_t "      "
  @indent_step_t "         "
  @indent_err__t "           "
  @indent_io___t "         │ "

  def run_background(context, []) do
    context
  end

  def run_background(context, steps) do
    print_background()
    run_steps(context, steps)
  end

  def run_scenario(context, scenario) do
    print_scenario(scenario)
    run_steps(context, scenario.steps)
  end

  defp run_steps(context, steps) do
    # If there was a Background in the feature, the setup will
    # return {:ok, context} | :pending | {:error, …}
    # so we unwrap a :ok tuple but keep other values as is
    context = uok(context)
    contexts_mods = Application.get_env(:taro, :contexts)

    actions = Compiler.extract_actions(contexts_mods)

    results =
      steps
      |> match_steps(actions)
      |> Enum.scan({:ok, context}, &run_step/2)

    results
    |> Enum.each(fn
      {:error, {:exception, e, stack}} ->
        # Make ExUnit fail
        reraise e, stack

      :pending ->
        raise "Some tests were pending/skipped"

      _ ->
        :ok
    end)

    List.last(results)
  end

  defp match_steps(steps, actions, matched \\ [], errors \\ [], true_keyword \\ "Given")

  defp match_steps([step | steps], actions, matched, errors, true_keyword) do
    {matched, errors} =
      case match_step(step, actions) do
        {:ok, step_action} ->
          {[step_action | matched], errors}

        {:error, {:no_action, orphan_step}} ->
          # Prepare a real keyword for the snippet formatter
          orphan_step =
            case Map.get(orphan_step, :keyword) do
              keyword when keyword in ["Given", "When", "Then"] -> orphan_step
              _ -> Map.put(orphan_step, :keyword, true_keyword)
            end

          {matched, [{:error, {:no_action, orphan_step}} | errors]}
      end

    true_keyword =
      case Map.get(step, :keyword) do
        true_kw when true_kw in ["Given", "When", "Then"] -> true_kw
        _ -> true_keyword
      end

    match_steps(steps, actions, matched, errors, true_keyword)
  end

  defp match_steps([], actions, matched, errors, _true_keyword) do
    {matched_steps, unmatched_steps} = {:lists.reverse(matched), :lists.reverse(errors)}

    if length(unmatched_steps) > 0 do
      unmatched_steps
      |> Enum.each(&print_unmatched_step/1)

      snippets =
        unmatched_steps
        |> Enum.map(&generate_snippet/1)
        |> Enum.join("\n\n")

      contexts_mods =
        actions
        |> Enum.map(& &1.mod)
        |> Enum.uniq()

      contexts_mods_list =
        contexts_mods
        |> Enum.map(&("- " <> to_string(&1)))
        |> Enum.join("\n")

      err_text = """

        Some steps could not be matched to an action within any of the context
        modules used.

        Context Modules:
        #{contexts_mods_list}

        You can add the following snippet#{if(length(unmatched_steps) > 1, do: "s", else: "")} to any of those modules modules.

      #{snippets}
      """

      IO.puts(IO.ANSI.format([:yellow, err_text]))

      # await IO output
      Process.sleep(100)
      raise "Some steps counld'nt be matched to a context function"
    end

    matched_steps
  end

  defp match_step(%{keyword: step_type, text: text} = step, actions) do
    tokens = StepTokenizer.tokenize(step.text)

    Enum.find_value(actions, fn action ->
      case Action.match_step(action, step, tokens) do
        {:error, _} -> nil
        {:ok, action} -> action
      end
    end)
    |> case do
      nil -> {:error, {:no_action, step}}
      action -> {:ok, {step, action}}
    end
  end

  defp run_step({step, action}, previous) do
    {call_result, io_output} =
      case previous do
        {:ok, context} ->
          ref = make_ref()
          parent = self()

          captured =
            ExUnit.CaptureIO.capture_io(fn ->
              call_result = Context.call(context, action)
              send(parent, {ref, call_result})
            end)

          receive do
            {^ref, result} -> {result, captured}
          end

        _ ->
          {:skipped, ""}
      end

    print_step(step, action, call_result, io_output)
    call_result
  end

  def print_feature(%{name: name, description: description}) do
    # skip the ExUnit dot
    [
      "\n",
      @indent_feat__,
      IO.ANSI.format([:bright, "Feature: "]),
      name,
      if(description == "", do: [], else: "\n"),
      indent_text(description, @indent_feat_t)
    ]
    |> output_print()
  end

  defp print_background() do
    # skip the ExUnit dot
    ["\n", @indent_scen__, IO.ANSI.format([:bright, "Background:"])]
    |> output_print
  end

  defp print_scenario(scenario) do
    # skip the ExUnit dot
    [
      "\n",
      @indent_scen__,
      IO.ANSI.format([:bright, "Scenario: "]),
      scenario.name
    ]
    |> output_print
  end

  defp print_step(step, action, result, step_io_output) do
    color = step_print_color(result)

    text =
      case action do
        :no_action -> IO.ANSI.format([color, step.text])
        action -> bright_args(action.print_tokens, color) |> Enum.intersperse(" ")
      end

    [
      @indent_step_t,
      step.keyword,
      " ",
      text,
      IO.ANSI.format([color, step_print_extra(result)]),
      if(step_io_output != "", do: ["\n", step_print_io(step_io_output)], else: [])
    ]
    |> output_print
  end

  defp bright_args([{:text, text} | rest], color),
    do: [IO.ANSI.format([color, text]) | bright_args(rest, color)]

  defp bright_args([{:arg, value} | rest], color),
    do: [IO.ANSI.format([:bright, to_string(value)]) | bright_args(rest, color)]

  defp bright_args([], _), do: []

  defp output_print(iolist) do
    IO.puts(iolist)
  end

  defp step_print_color({:ok, context}), do: :green
  defp step_print_color({:error, {:exception, e, stack}}), do: :red
  defp step_print_color({:error, reason}), do: :red
  defp step_print_color(:pending), do: :yellow
  defp step_print_color(:skipped), do: :cyan

  defp step_print_extra({:ok, context}) do
    []
  end

  defp step_print_extra({:error, {:exception, e, stack}}) do
    ["\n", @indent_err__t, "Exception: ", Exception.message(e)]
  end

  defp step_print_extra({:error, reason}) do
    ["\n", @indent_err__t, "Error: ", inspect(reason)]
  end

  defp step_print_extra(:pending) do
    []
  end

  defp step_print_extra(:skipped) do
    []
  end

  defp step_print_io(captured) do
    [
      String.trim_trailing(indent_text(captured, @indent_io___t), "\n")
    ]
  end

  defp print_unmatched_step({:error, {:no_action, step}}) do
    print_step(step, :no_action, {:error, "No action found"}, "")
  end

  defp generate_snippet({:error, {:no_action, step}}) do
    SnippetFormatter.format_snippet(step)
    |> indent_text("  ")
  end

  defp indent_text(string, ws) when is_binary(string) and is_binary(ws) do
    ws <>
      (string
       |> String.trim_trailing("\n")
       |> String.split("\n")
       |> Enum.join("\n#{ws}"))
  end
end
