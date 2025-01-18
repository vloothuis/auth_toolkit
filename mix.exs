defmodule AuthToolkit.MixProject do
  use Mix.Project

  def project do
    [
      app: :auth_toolkit,
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
      {:swoosh, "~> 1.7"},
      {:argon2_elixir, ">= 4.0.0"},
      {:gettext, ">= 0.22.0"},
      {:mjml_eex, "~> 0.12.0"},
      {:phoenix, ">= 1.7.9", override: true},
      {:phoenix_ecto, ">= 4.4.2"},
      {:phoenix_html, ">= 3.0.0"},
      {:phoenix_live_view, ">= 0.20.1"},
      # Dev
      {:phoenix_live_reload, ">= 1.5.0", only: :dev},
      # Dev-test
      {:mix_test_watch, ">= 1.0.0", only: [:dev, :test], runtime: false},
      {:styler, ">= 0.9.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7.7-rc.0", only: [:dev, :test], runtime: false},
      {:esbuild, "~> 0.8", only: [:dev, :test]},
      {:bandit, "~> 1.5", only: [:dev, :test]},
      # Test
      {:faker, ">= 0.17.0", only: [:test]},
      {:floki, ">= 0.30.0", only: [:test]},
      {:mock, "~> 0.3.0", only: [:test]}
    ]
  end

  defp aliases do
    [
      dev: "run --no-halt dev.exs",
      "ecto.reset": ["ecto.drop", "ecto.create", "ecto.migrate"],
      "test.reset": ["ecto.drop --quiet", "test.setup"],
      "test.setup": ["ecto.create --quiet", "ecto.migrate --quiet"],
      "test.ci": [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "credo --strict",
        "test --raise",
        "dialyzer"
      ],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["esbuild js", "esbuild css"],
      "assets.deploy": [
        "esbuild css --minify",
        "esbuild js --minify",
        "phx.digest"
      ]
    ]
  end
end
