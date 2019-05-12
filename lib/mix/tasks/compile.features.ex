defmodule Mix.Tasks.Compile.Features do
  # use Mix.Task.Compiler

  # @manifest "compile.features"

  # def run(_args) do
  #   project = Mix.Project.config()
  #   dest = Mix.Project.compile_path(project)
  #   # Mix.Util
  #   app = project[:app]
  #   features_sources = app
  #     |> Application.app_dir("priv") #|> File.ls
  #     |> Path.join("features")
  #     |> List.wrap
  #     |> Mix.Utils.extract_files([:feature])
  #     # @todo compile only stale when app is stable
  #     # |> Mix.Utils.extract_stale(manifests())
  #   # IO.inspect(features_sources, pretty: true, label: "features_sources")
  #   compile_opts = []
  #   features_sources
  #   |> Task.async_stream(&compile_feature(&1, compile_opts))
  #   |> Enum.reduce([], fn(compiled, acc) -> [compiled|acc] end)
  #   |> IO.inspect(pretty: true)

  #   :ok
  # end

  # defp compile_feature(file, _opts) do
  #   file
  #   # |> File.read!()
  #   # |> Gherkin.parse()
  #   # |> Macro.escape()
  #   # |> IO.inspect(pretty: true)
  # end

  # def manifests, do: [manifest()]

  # defp manifest, do: Path.join(Mix.Project.manifest_path(), @manifest)
end
