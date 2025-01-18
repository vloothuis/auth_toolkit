defmodule AuthToolkit.UserConfirmationCode do
  @moduledoc false
  use Ecto.Schema

  alias AuthToolkit.User

  # Time after which confirmation codes expire (in minutes)
  @expire_after 15

  @primary_key false
  schema "auth_toolkit_user_confirmation_codes" do
    field(:code, :string, primary_key: true)
    belongs_to(:user, User, primary_key: true)
    field(:expires_at, :utc_datetime_usec)
  end

  @doc """
  Returns true if the confirmation code has expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.after?(DateTime.utc_now(), expires_at)
  end

  def expires_at do
    DateTime.add(DateTime.utc_now(), @expire_after, :minute)
  end
end
