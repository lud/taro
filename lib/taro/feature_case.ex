defmodule Taro.FeatureCase do
  alias Gherkin.Elements.Feature
  alias Gherkin.Elements.Scenario
  alias Gherkin.Elements.Step
  alias Taro.Context
  alias Taro.Context.Handler
  alias Taro.Context.Compiler
  import Ark.Wok

  defmacro __using__(opts) do
    unless Process.whereis(Taro.Supervisor) do
      raise "cannot use Taro.FeatureCase without starting the Taro application, " <>
              "please call Taro.start() in test_helper.exs or explicitly start the :taro app"
    end

    file_name = opts[:file]
    source = File.read!(file_name)
    # We use the parser directly in order to provide the file_name
    gherkin_tree = Gherkin.Parser.parse_feature(source, file_name)
    %Feature{scenarios: scenarios, background_steps: background_steps} = gherkin_tree

    quoted_setup = build_feature_setup(gherkin_tree)
    quoted_scenario_setup = build_scenario_setup(background_steps)
    quoted_scenaro_tests = build_scenario_tests(scenarios)

    quote location: :keep do
      use ExUnit.Case

      def __feature__(), do: unquote(Macro.escape(gherkin_tree))

      unquote(quoted_setup)
      unquote(quoted_scenario_setup)
      unquote(quoted_scenaro_tests)
    end
  end

  defp build_feature_setup(tree) do
    %Feature{name: name, description: description} = tree
    feature = %{name: name, description: description}

    quote location: :keep do
      setup_all do
        Taro.FeatureCase.print_feature(unquote(Macro.escape(feature)))
      end
    end
  end

  defp build_scenario_setup(background_steps) do
    # We map on the :taro_test === true to run the setup.
    # This prevents from running the setup for tests defined in
    # The feature .exs file
    quote location: :keep do
      ExUnit.Callbacks.setup exunit_context do
        case Map.fetch(exunit_context, :taro_test) do
          {:ok, true} ->
            contexts_mods = Application.get_env(:taro, :contexts)

            context =
              taro_context =
              contexts_mods
              |> Taro.Context.new()
              |> Taro.FeatureCase.run_background(unquote(Macro.escape(background_steps)))

            %{taro_context: taro_context}

          _otherwise ->
            :ok
        end
      end
    end
  end

  defp build_scenario_tests(scenarios) do
    scenarios
    |> Enum.map(&build_scenario_test/1)
  end

  defp build_scenario_test(scenario) do
    quote location: :keep do
      @tag taro_test: true
      test unquote(scenario.name), %{taro_context: taro_context} do
        Taro.FeatureCase.run_scenario(taro_context, unquote(Macro.escape(scenario)))
      end
    end
  end

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
    handlers = Compiler.extract_steps_handlers(contexts_mods)

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
        nil -> nil
        captures -> Handler.set_captures(handler, captures)
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
  @step_io_indent @step_indent <> " ｜ "

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
      step.keyword,
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

  defp step_print_color(:skipped), do: IO.ANSI.blue()

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
    [
      IO.ANSI.red(),
      "#{step.keyword} #{step.text} : No handler found",
      IO.ANSI.reset()
    ]
    |> IO.puts()
  end

  defp generate_snippet({:error, {:no_handler, step}}) do
    fun = Slugger.slugify_downcase(step.text, ?_)

    """
    @step "#{step.text}"
    def #{fun}(context) do
      raise Taro.Exception.Pending, message: "TODO #{__MODULE__}.#{fun}"
    end
    """
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
