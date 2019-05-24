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

    quoted_scenario_setup = build_scenario_setup(background_steps)
    quoted_scenaro_tests = build_scenario_tests(scenarios)

    quote location: :keep do
      use ExUnit.Case

      def __feature__(), do: unquote(Macro.escape(gherkin_tree))

      unquote(quoted_scenario_setup)
      unquote(quoted_scenaro_tests)
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
    run_steps(context, steps)
  end

  def run_scenario(context, scenario) do
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
    IO.write("#{step.keyword} #{step.text}")

    call_result =
      case previous do
        {:ok, context} -> Context.call(context, handler)
        _ -> :skipped
      end

    IO.puts(["  ", format_call_result(call_result)])
    call_result
  end

  defp format_call_result({:ok, context}) do
    [IO.ANSI.light_green(), "OK", IO.ANSI.reset()]
  end

  defp format_call_result({:error, {:exception, e, stack}}) do
    [IO.ANSI.light_red(), "Exception: #{Exception.message(e)}", IO.ANSI.reset()]
  end

  defp format_call_result({:error, reason}) do
    [IO.ANSI.light_red(), "Error: #{inspect(reason)}", IO.ANSI.reset()]
  end

  defp format_call_result(:pending) do
    [IO.ANSI.yellow(), "Pending", IO.ANSI.reset()]
  end

  defp format_call_result(:skipped) do
    [IO.ANSI.light_blue(), "Skipped", IO.ANSI.reset()]
  end

  defp print_unmatched_step({:error, {:no_handler, step}}) do
    [
      IO.ANSI.light_red(),
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
    |> indent("  ")
  end

  defp indent(string, ws) do
    ws <>
      (string
       |> String.split("\n")
       |> Enum.join("\n#{ws}"))
  end
end
