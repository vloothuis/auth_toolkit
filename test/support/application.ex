defmodule AuthToolkit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    dbg("ASFD")

    children = [
      AuthToolkit.TestRepo,
      {Ecto.Migrator, repos: Application.fetch_env!(:auth_toolkit, :ecto_repos), skip: skip_migrations?()},
      {Phoenix.PubSub, name: AuthToolkit.PubSub},
      # Start to serve requests, typically the last entry
      AuthToolkitWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AuthToolkit.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AuthToolkitWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations? do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil
  end
end
