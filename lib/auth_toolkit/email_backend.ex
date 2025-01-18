defmodule AuthToolkit.EmailBackend do
  @moduledoc false
  alias AuthToolkit.User

  @callback send_account_confirmation(User.t(), String.t()) :: {:ok, term()} | {:error, term()}
  @callback send_confirmation_code(User.t(), String.t()) :: {:ok, term()} | {:error, term()}
  @callback send_reset_password_code(User.t(), String.t()) :: {:ok, term()} | {:error, term()}

  def get do
    Application.get_env(:auth_toolkit, :email_backend, AuthToolkit.DefaultEmailBackend)
  end
end
