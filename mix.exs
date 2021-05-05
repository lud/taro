defmodule Taro.MixProject do
  use Mix.Project

  def project do
    [
      app: :taro,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Taro.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      {:gherkin, "~> 1.6"},
      # {:gherkin, github: "cabbage-ex/gherkin", branch: "master"},
      {:ark, "~> 0.1.0"},
      {:slugger, "~> 0.3.0"}
      # {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false}
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  # defp elixirc_paths(:test), do: ["lib"]
  # defp elixirc_paths(_), do: ["lib"]
end
