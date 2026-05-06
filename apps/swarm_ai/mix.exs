defmodule SwarmAi.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/frontman-ai/frontman/tree/main/apps/swarm_ai"

  def project do
    [
      app: :swarm_ai,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "SwarmAi",
      description:
        "A simple agentic loop for Elixir. Bring your own LLM and tools, get streaming, tool execution, child agents, and telemetry out of the box.",
      source_url: @source_url,
      dialyzer: [
        plt_add_apps: [:mix],
        plt_local_path: "priv/plts"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:typedstruct, "~> 0.5"},
      {:jason, "~> 1.2"},
      {:uuidv7, "~> 1.0"},
      {:telemetry, "~> 1.4"},
      {:req_llm, github: "itayadler/req_llm", branch: "fix/openai-codex-token-limit"},
      # Dev/Test
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
