defmodule Mix.Tasks.Compile.Features do
  use Mix.Task.Compiler
  import Ark.Wok, only: [uok!: 1]
  alias Gherkin.Elements.Feature
  alias Gherkin.Elements.Scenario
  alias Gherkin.Elements.Step
  @manifest "compile.features"

  def run(_args) do
    project = Mix.Project.config()
    Process.sleep(1000)
    dest = Mix.Project.compile_path(project)
    # Mix.Util
    features_sources =
      project[:elixirc_paths]
      |> Mix.Utils.extract_files([:feature])

    # @todo compile only stale when app is stable
    # |> Mix.Utils.extract_stale(manifests())
    compile_opts = [app: project[:app]]

    features_sources
    |> Task.async_stream(&compile_feature(&1, compile_opts))
    |> Stream.map(&uok!/1)
    |> Enum.to_list()

    # # |> Enum.reduce([], fn(compiled, acc) -> [compiled|acc] end)
    # |> IO.inspect(pretty: true)
    _args
  end

  defp compile_feature(file_name, opts) do
    source = File.read!(file_name)
    # We use the parser directly in order to provide the file_name
    ghdata = Gherkin.Parser.parse_feature(source, file_name)
    # """
    # todo create a module
    #  - export the feature file as source()
    #  - for each scenario, match the contexts regexes and describe the
    #    call to the context module found (or throw if not found) with
    #    args
    #  - create a ExUnit test for each scenario.
    #  - in the test, just Enum.scan for run_step as in t.exs, no need
    #    to add the full code (printing step, evaluating return, 
    #    print error/success, …) in each module
    # # |> Macro.escape()
    # # |> IO.inspect(pretty: true)
    # """
    %{source: source, ghdata: ghdata}
    opts[:app]

    # @todo background steps

    module_name =
      [
        opts[:app] |> to_string |> Macro.camelize(),
        Taro,
        file_name |> Path.basename(".feature") |> Macro.camelize(),
        FeatureTest
      ]
      |> Module.concat()

    %Feature{background_steps: background_steps, scenarios: scenarios} = ghdata

    ghdata
    |> IO.inspect(pretty: true)

    # Module.create(module_name,)
  end

  def manifests, do: [manifest()]

  defp manifest, do: Path.join(Mix.Project.manifest_path(), @manifest)
end
