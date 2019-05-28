defmodule Taro.FeatureCase do
  alias Gherkin.Elements.Feature
  # alias Gherkin.Elements.Scenario
  # alias Gherkin.Elements.Step
  # alias Taro.Context
  # alias Taro.Context.Action

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
        Taro.FeatureRunner.print_feature(unquote(Macro.escape(feature)))
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
              |> Taro.FeatureRunner.run_background(unquote(Macro.escape(background_steps)))

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
        Taro.FeatureRunner.run_scenario(taro_context, unquote(Macro.escape(scenario)))
      end
    end
  end
end
