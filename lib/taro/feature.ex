defmodule Taro.Feature do
  alias Gherkin.Elements.Feature

  defp ensure_started() do
    unless Process.whereis(Taro.Supervisor) do
      raise "cannot use Taro.Feature without starting the Taro application, " <>
              "please call Taro.start() from your test or from test_helper.exs"
    end
  end

  defmacro __using__(opts) do
    opts =
      opts
      |> ensure_file_opts(__CALLER__)
      |> fetch_source()
      |> append_contexts(__CALLER__)

    feature = parse_feature(opts)
    %Feature{scenarios: scenarios, background_steps: background_steps} = feature

    quoted_setup = build_feature_setup(feature)
    quoted_scenario_setup = build_scenario_setup(background_steps, opts)
    quoted_scenaro_tests = build_scenario_tests(scenarios)

    quote location: :keep do
      unquote(quoted_setup)
      unquote(quoted_scenario_setup)
      unquote(quoted_scenaro_tests)
    end
  end

  defp ensure_file_opts(opts, env) do
    case Keyword.fetch(opts, :file) do
      {:ok, file} when is_binary(file) ->
        opts

      {:ok, other} ->
        raise ArgumentError,
          message: """
          invalid option :file given to `use Taro.Feature` in #{env.file}

              The :file option for using Taro.Feature is read at compile time and must
              be a litteral String.

              Given value was:

                #{Macro.to_string(other)}
          """

      :error ->
        raise "the :file option is required"
    end
  end

  defp fetch_source(opts) do
    file = Keyword.fetch!(opts, :file)

    case File.read(file) do
      {:ok, source} -> Keyword.put(opts, :source, source)
      {:error, _} = err -> raise "could not read file #{file}: #{inspect(err)}"
    end
  end

  defp append_contexts(opts, env) do
    contexts =
      case Keyword.get(opts, :contexts, []) do
        list when is_list(list) ->
          list

        other ->
          raise ArgumentError,
            message: """
            invalid option :contexts given to `use Taro.Feature` in #{env.file}

                The :contexts option for using Taro.Feature must be a list of
                modules.

                Given value was:

                  #{Macro.to_string(other)}
            """
      end

    # replace the contexts option with itself plus the contexts from
    # configuration
    opts
    |> Keyword.put(:contexts, contexts ++ Application.get_env(:taro, :contexts, []))
  end

  defp parse_feature(opts) do
    Gherkin.Parser.parse_feature(opts[:source], opts[:file])
    |> Map.update!(:background_steps, &cast_steps/1)
    |> Map.update!(:scenarios, fn scenarios ->
      Enum.map(scenarios, fn scenario ->
        Map.update!(scenario, :steps, &cast_steps/1)
      end)
    end)
  end

  defp cast_steps(list) when is_list(list) do
    Enum.map(list, &cast_step(&1))
  end

  defp cast_step(%{__struct__: step_mod} = step) do
    step
    |> Map.from_struct()
    |> Map.put(:keyword, step_keyword(step_mod))
  end

  defp step_keyword(Gherkin.Elements.Steps.Given), do: "Given"
  defp step_keyword(Gherkin.Elements.Steps.And), do: "And"
  defp step_keyword(Gherkin.Elements.Steps.When), do: "When"
  defp step_keyword(Gherkin.Elements.Steps.Then), do: "Then"

  defp build_feature_setup(tree) do
    %Feature{name: name, description: description} = tree
    feature = %{name: name, description: description}

    quote location: :keep do
      setup_all do
        Taro.FeatureRunner.print_feature(unquote(Macro.escape(feature)))
      end
    end
  end

  defp build_scenario_setup(background_steps, opts) do
    contexts = Keyword.fetch!(opts, :contexts)

    # We map on the :taro_test === true to run the setup.
    # This prevents from running the setup for classic tests defined
    # in the .exs file using the feature
    quote location: :keep do
      ExUnit.Callbacks.setup exunit_context do
        case Map.fetch(exunit_context, :taro_test) do
          {:ok, true} ->
            contexts_mods = unquote(contexts)

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
