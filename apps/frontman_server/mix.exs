defmodule FrontmanServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :frontman_server,
      version: "0.0.1",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() == :prod,
      deps: deps(),
      compilers: [:boundary, :phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      licenses: ["AGPL-3.0-only"],
      hex: [
        ignore_advisories: [
          "EEF-CVE-2026-95105",
          "EEF-CVE-2026-94206"
        ]
      ],
      releases: [
        frontman_server: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent],
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        "coveralls.json": :test,
        "coveralls.cobertura": :test,
        "coveralls.lcov": :test,
        "coveralls.xml": :test
      ]
    ]
  end

  def application do
    [
      mod: {FrontmanServer.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:frontman_notifier, path: "../frontman_notifier", only: :test, runtime: false},
      {:swarm_ai, path: "../swarm_ai"},
      {:boundary, "~> 0.10", runtime: false},
      {:bcrypt_elixir, "~> 3.0"},
      {:anubis_mcp, "== 2.2.0"},
      {:cloak_ecto, "~> 1.3"},
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:polymorphic_embed, "~> 5.0"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.2.1"},
      {:phoenix_live_dashboard, "~> 0.9.0"},
      {:req_llm,
       github: "agentjido/req_llm",
       ref: "5845012e032593be225b2eb6b8e3dfbefb68223c",
       override: true},
      {:llm_db,
       github: "agentjido/llmdb", ref: "29f7e54fb83b58272c0f13aab47accbda2bed597", override: true},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:oban, "~> 2.20"},
      {:req, "~> 0.5"},
      {:html2markdown, "~> 0.3"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:jose, "~> 1.11"},
      {:jsv, "~> 0.22"},
      {:dns_cluster, "~> 0.3.0"},
      {:bandit, "~> 1.5"},
      {:zoi, "~> 0.14"},
      {:dotenvy, "~> 1.1"},
      {:sentry, "~> 14.0"},
      {:workos, "~> 3.0"},
      {:paper_tiger, "~> 1.0", only: [:test]},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.18", only: :dev, runtime: false},
      {:bypass, "~> 2.1", only: :test},
      {:cowboy,
       github: "ninenines/cowboy",
       ref: "3a630c07e1521abf63a1b9ea080509aa1337b60d",
       only: :test,
       override: true},
      {:cowlib,
       github: "ninenines/cowlib",
       ref: "a3b15e29b3067644bfd580246c87f7af7a90b3b8",
       only: :test,
       override: true},
      {:ranch, "~> 1.8", only: :test, override: true},
      {:mox, "~> 1.2", only: :test}
    ]
  end
end
