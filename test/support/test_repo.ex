defmodule AccountToolkit.TestRepo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :account_toolkit,
    adapter: Ecto.Adapters.Postgres
end
