defmodule FrontmanNotifier.MixProject do
  use Mix.Project

  def project do
    [
      app: :frontman_notifier,
      version: "0.0.1",
      elixir: "~> 1.19",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_local_path: "priv/plts"],
      releases: [
        frontman_notifier: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent],
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {FrontmanNotifier.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:postgrex, "~> 0.22"},
      {:req, "~> 0.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
