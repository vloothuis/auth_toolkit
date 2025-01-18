import Config

config :auth_toolkit, AuthToolkit.Mailer, adapter: Swoosh.Adapters.Local

config :auth_toolkit, AuthToolkit.TestRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "auth_toolkit_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  priv: "priv",
  log: false

config :auth_toolkit, AuthToolkitWeb.Endpoint,
  pubsub_server: AuthToolkit.PubSub,
  render_errors: [view: AuthToolkitWeb.Test.ErrorView],
  live_view: [signing_salt: "GB57bDreRQYnbQ2H"],
  secret_key_base: "15CMbPLqBn2KFKuuaNOS2oRTOHwUfhKr91h1qVe0c5NGXa25cAYbfgKYFo5mSPPW"

config :auth_toolkit, :endpoint, AuthToolkitWeb.Endpoint
config :auth_toolkit, ecto_repos: [AuthToolkit.TestRepo]

config :auth_toolkit,
  email_factory: AuthToolkit.TestEmailFactory,
  mailer: AuthToolkit.Mailer,
  repo: AuthToolkit.TestRepo,
  promoter_id_schema_type: :integer,
  applicant_id_schema_type: :integer

config :esbuild,
  version: "0.17.11",
  js: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static --external:/fonts/* --external:/images/*),
    cd: Path.expand("./assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  css: [
    args: ~w(css/app.css --bundle --outdir=../priv/static --external:/fonts/* --external:/images/*),
    cd: Path.expand("./assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :logger, level: :warning

config :swoosh, :api_client, false
