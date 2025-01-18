defmodule AccountToolkit.MixProject do
  use Mix.Project

  def project do
    [
      app: :account_toolkit,
      version: "0.1.0",
      config_path: "./config/config.exs",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix, :postgrex],
        plt_core_path: "_build/#{Mix.env()}",
        flags: [:error_handling, :missing_return, :underspecs]
      ],
      preferred_cli_env: [
        "test.ci": :test,
        "test.reset": :test,
        "test.setup": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
      {:ecto_sql, ">= 3.6.0"},
      {:mox, "~> 1.0", only: :test},
      {:tzdata, ">= 1.1.0"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.5"},
      {:argon2_elixir, ">= 4.0.0"},
      {:faker, ">= 0.17.0", only: :test},
      {:mix_test_watch, ">= 1.0.0", only: [:dev, :test], runtime: false},
      {:styler, ">= 0.9.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7.7-rc.0", only: [:test, :dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:test, :dev], runtime: false}
    ]
  end

  defp aliases do
    [
      "ecto.reset": ["ecto.drop", "ecto.create", "ecto.migrate"],
      "test.reset": ["ecto.drop --quiet", "test.setup"],
      "test.setup": ["ecto.create --quiet", "ecto.migrate --quiet"],
      "test.ci": [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "credo --strict",
        "test --raise",
        "dialyzer"
      ]
    ]
  end
end
