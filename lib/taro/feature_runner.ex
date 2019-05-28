defmodule Taro.FeatureRunner do
  import Ark.Wok
  # alias Gherkin.Elements.Scenario
  alias Taro.Context.Compiler
  alias Gherkin.Elements.Step
  alias Taro.SnippetFormatter

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

  def run_steps(context, steps) do
    # If there was a Background in the feature, the setup will
    # return {:ok, context} | :pending | {:error, …}
    # so we unwrap a :ok tuple but keep other values as is
    context = uok(context)
    contexts_mods = Application.get_env(:taro, :contexts)
    handlers = Compiler.extract_actions(contexts_mods)

    results =
      steps
      |> match_steps(handlers)
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

  defp match_steps(steps, handlers) do
    {good_steps, bad_steps} =
      steps
      |> Enum.map(&match_step(&1, handlers))
      |> Enum.split_with(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    if length(bad_steps) > 0 do
      bad_steps
      |> Enum.each(&print_unmatched_step/1)

      IO.puts("You can add the following snippets to any of your context modules :\n")

      snippets =
        bad_steps
        |> Enum.map(&generate_snippet/1)
        |> Enum.join("\n")
        |> IO.puts()

      # await IO output
      Process.sleep(100)
      raise "Some steps counld'nt be matched to a context function"
    end

    good_steps |> Enum.map(&uok!/1)
  end

  defp match_step(%Step{text: text} = step, handlers) do
    Enum.find_value(handlers, fn handler ->
      %{regex: regex} = handler
      # IO.puts "does #{inspect regex} match « #{text} » ?: #{Regex.match?(regex, text)}"
      case Regex.run(regex, text, capture: :all_but_first) do
        nil ->
          nil

        captures ->
          Handler.set_captures(handler, captures)
      end
    end)
    |> case do
      nil -> {:error, {:no_handler, step}}
      handler -> {:ok, {step, handler}}
    end
  end

  defp run_step({step, handler}, previous) do
    {call_result, io_output} =
      case previous do
        {:ok, context} ->
          ref = make_ref()
          parent = self()

          captured =
            ExUnit.CaptureIO.capture_io(fn ->
              call_result = Context.call(context, handler)
              send(parent, {ref, call_result})
            end)

          receive do
            {^ref, result} -> {result, captured}
          end

        _ ->
          {:skipped, ""}
      end

    print_step(step, call_result, io_output)
    call_result
  end

  @feature_indent ""
  @feature_text_indent @feature_indent <> "  "
  @scenario_indent "  "
  @scenario_text_indent @scenario_indent <> "  "
  @step_indent "    "
  @error_indent @step_indent <> "  "
  @step_io_indent @step_indent <> " │ "

  def print_feature(%{name: name, description: description}) do
    # skip the ExUnit dot
    [
      "\n",
      @feature_indent,
      IO.ANSI.bright(),
      "Feature: ",
      IO.ANSI.reset(),
      name,
      if(description == "", do: [], else: "\n"),
      indent_text(description, @feature_text_indent)
    ]
    |> output_print()
  end

  defp print_background() do
    # skip the ExUnit dot
    ["\n", @scenario_indent, IO.ANSI.bright(), "Background:", IO.ANSI.reset()]
    |> output_print
  end

  defp print_scenario(scenario) do
    # skip the ExUnit dot
    [
      "\n",
      @scenario_indent,
      IO.ANSI.bright(),
      "Scenario: ",
      IO.ANSI.reset(),
      scenario.name,
      if(scenario.description == "",
        do: [],
        else: ["\n", indent_text(scenario.description, @scenario_text_indent)]
      )
    ]
    |> output_print
  end

  defp print_step(step, result, step_io_output) do
    [
      @step_indent,
      step_print_color(result),
      IO.ANSI.bright(),
      step.keyword,
      IO.ANSI.reset(),
      step_print_color(result),
      " ",
      step.text,
      step_print_extra(result),
      IO.ANSI.reset(),
      if(step_io_output != "", do: ["\n", step_print_io(step_io_output)], else: [])
    ]
    |> output_print
  end

  defp output_print(iolist) do
    [iolist, IO.ANSI.reset()]
    |> IO.puts()
  end

  defp step_print_color({:ok, context}), do: IO.ANSI.green()

  defp step_print_color({:error, {:exception, e, stack}}), do: IO.ANSI.red()

  defp step_print_color({:error, reason}), do: IO.ANSI.red()

  defp step_print_color(:pending), do: IO.ANSI.yellow()

  defp step_print_color(:skipped), do: IO.ANSI.cyan()

  defp step_print_extra({:ok, context}) do
    []
  end

  defp step_print_extra({:error, {:exception, e, stack}}) do
    ["\n", @error_indent, "Exception: ", Exception.message(e)]
  end

  defp step_print_extra({:error, reason}) do
    ["\n", @error_indent, "Error: ", inspect(reason)]
  end

  defp step_print_extra(:pending) do
    []
  end

  defp step_print_extra(:skipped) do
    []
  end

  defp step_print_io(captured) do
    [
      String.trim_trailing(indent_text(captured, @step_io_indent), "\n")
    ]
  end

  defp print_unmatched_step({:error, {:no_handler, step}}) do
    print_step(step, {:error, "No handler found"}, "")
  end

  defp generate_snippet({:error, {:no_handler, step}}) do
    SnippetFormatter.format_snippet(step)
    |> indent_text("  ")
  end

  defp indent_text(string, ws) do
    ws <>
      (string
       |> String.trim_trailing("\n")
       |> String.split("\n")
       |> Enum.join("\n#{ws}"))
  end
end
