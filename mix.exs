defmodule Alur.MixProject do
  use Mix.Project

  def project do
    [
      app: :alur,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      usage_rules: usage_rules()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Alur.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:reach, "~> 2.0"},
      {:ex_dna, "~> 1.0"},
      {:igniter, "~> 0.6"},
      {:usage_rules, "~> 1.0"},
      {:dialyxir, "~> 1.0", runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:phoenix_test, "~> 0.12.1", only: :test, runtime: false},
      {:phoenix, "~> 1.8.0"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind alur", "esbuild alur"],
      "assets.deploy": [
        "tailwind alur --minify",
        "esbuild alur --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format --check-formatted",
        "test",
        "credo --strict",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ]
    ]
  end

  defp usage_rules() do
    [
      file: "AGENTS.md",
      usage_rules: {:all, link: :markdown},
      skills: [
        location: ".agents/skills",
        build: [
          "phoenix-framework": [
            description:
              "Use this skill working with Phoenix Framework. Consult this when working with the web layer, controllers, views, liveviews, database/Ecto schemas and migrations, HTTP requests with Req, Swoosh mailer, and assets.",
            usage_rules: [
              :phoenix,
              ~r/^phoenix_/,
              :ecto,
              :ecto_sql,
              :ecto_sqlite3,
              :req,
              :swoosh,
              :tailwind,
              :esbuild,
              :phoenix_test
            ]
          ],
          igniter: [
            description:
              "Use this skill for code generation, project patching, AST analysis/transformations, and writing or running Igniter tasks.",
            usage_rules: [:igniter]
          ],
          "code-analysis": [
            description:
              "Use this skill for code quality, linting, architecture boundaries, type checking, and anti-pattern analysis with Credo, Dialyxir, Reach, ExDNA, and Elixir/OTP guidelines.",
            usage_rules: [:elixir, :otp, :credo, :dialyxir, :reach, :ex_dna]
          ]
        ]
      ]
    ]
  end
end
