import Config

config :account_toolkit, AccountToolkit.TestRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "account_toolkit_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  priv: "test/support",
  log: false

config :account_toolkit, ecto_repos: [AccountToolkit.TestRepo]

config :account_toolkit,
  email_factory: AccountToolkit.TestEmailFactory,
  mailer: AccountToolkit.Mailer,
  repo: AccountToolkit.TestRepo,
  promoter_id_type: :bigint,
  applicant_id_type: :bigint,
  promoter_id_schema_type: :integer,
  applicant_id_schema_type: :integer

config :swoosh, :api_client, false
