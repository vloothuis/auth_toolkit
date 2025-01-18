defmodule AuthToolkit.TestRepo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :auth_toolkit,
    adapter: Ecto.Adapters.Postgres
end
