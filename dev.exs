#######################################
# Development Server for Account Toolkit
#
# Usage:
#
# $ iex -S mix dev [flags]
#######################################
Logger.configure(level: :debug)

Application.put_env(:auth_toolkit, :endpoint, DemoWeb.Endpoint)
Application.put_env(:auth_toolkit, :repo, DemoWeb.Repo)

Application.put_env(:auth_toolkit, AuthToolkit.Mailer, adapter: Swoosh.Adapters.Local)


Application.put_env(:auth_toolkit, DemoWeb.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "auth_toolkit_demo",
  pool: Ecto.Adapters.SQL.Sandbox,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  priv: "priv",
  log: false
)

# Configures the endpoint
Application.put_env(:auth_toolkit, DemoWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "15CMbPLqBn2KFKuuaNOS2oRTOHwUfhKr91h1qVe0c5NGXa25cAYbfgKYFo5mSPPW",
  server: true,
  live_view: [signing_salt: "zXQRLEGA"],
  adapter: Bandit.PhoenixAdapter,
  http: [port: System.get_env("PORT") || 4002],
  debug_errors: true,
  check_origin: false,
  pubsub_server: Demo.PubSub,
  watchers: [
    js: {Esbuild, :install_and_run, [:js, ~w(--sourcemap=inline --watch)]},
    css: {Esbuild, :install_and_run, [:css, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"dist/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/phoenix/live_dashboard/(live|views)/.*(ex)$",
      ~r"lib/phoenix/live_dashboard/templates/.*(ex)$"
    ]
  ]
)

Application.put_env(:auth_toolkit, :rate_limiter, AuthToolkit.RateLimiter.Stub)



Application.put_env(:esbuild,
  :version, "0.17.11")
  Application.put_env(:esbuild,  :js, [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static --external:/fonts/* --external:/images/*),
    cd: Path.expand("./assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("./deps", __DIR__)}
  ])
  Application.put_env(:esbuild,  :css, [
    args: ~w(css/app.css --bundle --outdir=../priv/static --external:/fonts/* --external:/images/*),
    cd: Path.expand("./assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("./deps", __DIR__)}
  ])

defmodule DemoWeb.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :auth_toolkit,
    adapter: Ecto.Adapters.Postgres
end

defmodule DemoWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AuthToolkit.TestRepo,
      {Ecto.Migrator, repos: Application.fetch_env!(:auth_toolkit, :ecto_repos), skip: skip_migrations?()},
      {Phoenix.PubSub, name: AuthToolkit.PubSub},
      # Start to serve requests, typically the last entry
      DemoWeb.Endpoint
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

defmodule DemoWeb.PageController do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, :index) do
    content(conn, """
    <h2>Phoenix LiveDashboard Dev</h2>
    <a href="/dashboard">Open Dashboard</a>
    """)
  end

  def call(conn, :hello) do
    name = Map.get(conn.params, "name", "friend")
    content(conn, "<p>Hello, #{name}!</p>")
  end

  def call(conn, :get) do
    json(conn, %{
      args: conn.params,
      headers: Map.new(conn.req_headers),
      url: Phoenix.Controller.current_url(conn)
    })
  end

  defp content(conn, content) do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "<!doctype html><html><body>#{content}</body></html>")
  end

  defp json(conn, data) do
    body = Phoenix.json_library().encode_to_iodata!(data, pretty: true)

    conn
    |> Plug.Conn.put_resp_header("content-type", "application/json; charset=utf-8")
    |> Plug.Conn.send_resp(200, body)
  end
end

defmodule DemoWeb.Router do
  use Phoenix.Router

  require AuthToolkitWeb.Routes

  pipeline :browser do
    plug(:fetch_session)
    plug(:protect_from_forgery)
  end

  AuthToolkitWeb.Routes.routes(scope: "/auth")

  scope "/dev" do
    pipe_through(:browser)

    forward("/mailbox", Plug.Swoosh.MailboxPreview)
  end

  scope "/" do
    pipe_through(:browser)
    get("/", DemoWeb.PageController, :index)
    get("/get", DemoWeb.PageController, :get)
    get("/hello", DemoWeb.PageController, :hello)
    get("/hello/:name", DemoWeb.PageController, :hello)
  end
end

defmodule DemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :auth_toolkit

  @session_options [
    store: :cookie,
    key: "_live_view_key",
    signing_salt: "/ZEDsdfsffMnp5",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, session: @session_options]],
    longpoll: [connect_info: [:peer_data, session: @session_options]]
  )

  socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)

  plug(Phoenix.LiveReloader)
  plug(Phoenix.CodeReloader)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.Session, @session_options)

  plug(Plug.RequestId)
  plug(DemoWeb.Router)
end

Application.put_env(:phoenix, :serve_endpoints, true)

defmodule DemoUtils do
  @moduledoc false
  def migrate do
    Task.async(fn ->
      Ecto.Migrator.with_repo(DemoWeb.Repo, &Ecto.Migrator.run(&1, :up, all: true))
    end)
  end
end

fn ->
  children = []
  # children = [Demo.Postgres | children]

  children =
    children ++
      [
        {Phoenix.PubSub, [name: Demo.PubSub, adapter: Phoenix.PubSub.PG2]},
        DemoWeb.Repo,
        DemoWeb.Endpoint
      ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  case DemoWeb.Repo.__adapter__().storage_up(DemoWeb.Repo.config()) do
    :ok -> DemoUtils.migrate()
    {:error, :already_up} -> DemoUtils.migrate()
  end

  Process.sleep(:infinity)
end
|> Task.async()
|> Task.await(:infinity)
