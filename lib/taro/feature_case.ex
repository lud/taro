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
    ghdata = Gherkin.Parser.parse_feature(source, file_name)
    %Feature{scenarios: scenarios, background_steps: background_steps} = ghdata

    quoted_scenaro_tests = build_scenario_tests(scenarios)

    quote do
      use ExUnit.Case

      def __feature__(), do: unquote(Macro.escape(ghdata))

      unquote(quoted_scenaro_tests)
    end
  end

  defp build_scenario_tests(scenarios) do
    scenarios
    |> Enum.map(&build_scenario_test/1)
  end
  
  defp build_scenario_test(scenario) do
    quote do
      test "run some scenario" do
        Taro.FeatureCase.run_scenario(unquote(Macro.escape(scenario)), __MODULE__)
      end
    end
  end

  def run_scenario(scenario, feature_module) do
    contexts_mods = Application.get_env(:taro, :contexts)
    handlers = Compiler.extract_steps_handlers(contexts_mods)
    context = Context.new(contexts_mods, feature_module: feature_module)
    IO.puts "Using contexts\n\t#{contexts_mods |> Enum.join("\n\t")}"
    scenario
    |> Map.get(:steps)
    |> match_steps(handlers)
    |> Enum.scan({:ok, context}, &run_step/2)
  end

  defp match_steps(steps, handlers) do
    {good_steps, bad_steps} = steps
      |> Enum.map(&match_step(&1, handlers))
      |> Enum.split_with(fn 
          {:ok, _} -> true
          {:error, _} -> false
        end)
    if length(bad_steps) > 0 do
      bad_steps
        |> Enum.each(&print_unmatched_step/1)
      IO.puts "You can add the following snippets to any of your context modules :\n"
      snippets = bad_steps
        |> Enum.map(&generate_snippet/1)
        |> Enum.join("\n")
        |> IO.puts()
      Process.sleep(100) # await IO output
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
    IO.write "#{step.keyword} #{step.text}"
    call_result =
      case previous do
        {:ok, context} -> Context.call(context, handler)
        _ -> :skipped
      end
    IO.puts ["  ", format_call_result(call_result)]
    call_result
  end

  defp format_call_result({:ok, context}) do
    [IO.ANSI.light_green(), "OK", IO.ANSI.reset()]
  end
  defp format_call_result({:error, reason}) do
    [IO.ANSI.light_red(), "Error: #{inspect reason}", IO.ANSI.reset()]
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
        IO.ANSI.reset(),
    ]
    |> IO.puts()
  end

  defp generate_snippet({:error, {:no_handler, step}}) do
    fun = Slugger.slugify_downcase(step.text, ?_)
    """
    @step "#{step.text}"
    def #{fun}(_context) do
      raise Taro.Exception.Pending, message: "TODO #{__MODULE__}.#{fun}"
    end
    """
    |> indent("  ")
  end

  defp indent(string, ws) do
    ws <> (string 
    |> String.split("\n")
    |> Enum.join("\n#{ws}"))
  end


end
