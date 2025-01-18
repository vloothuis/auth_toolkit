defmodule AuthToolkit.Emails do
  @moduledoc false
  alias AuthToolkit.EmailBackend
  alias AuthToolkit.User

  defp format_code(confirmation_code) do
    ~r/\w{3}/
    |> Regex.scan(confirmation_code)
    |> List.flatten()
    |> Enum.join("-")
  end

  def send_account_confirmation(%User{} = user, confirmation_code) do
    EmailBackend.get().send_account_confirmation(user, format_code(confirmation_code))
  end

  def send_confirmation_code(%User{} = user, confirmation_code) do
    EmailBackend.get().send_confirmation_code(user, format_code(confirmation_code))
  end

  def send_reset_password_code(%User{} = user, confirmation_code) do
    EmailBackend.get().send_reset_password_code(user, format_code(confirmation_code))
  end
end
