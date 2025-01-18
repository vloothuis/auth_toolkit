defmodule AccountToolkit.UserConfirmationCode do
  @moduledoc false
  use Ecto.Schema

  alias AccountToolkit.User

  @primary_key false
  schema "account_toolkit_user_confirmation_codes" do
    field(:code, :string)
    belongs_to(:user, User)

    timestamps()
  end
end
