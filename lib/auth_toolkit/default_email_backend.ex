defmodule AuthToolkit.DefaultEmailBackend do
  @moduledoc false
  @behaviour AuthToolkit.EmailBackend

  import Swoosh.Email

  alias AuthToolkit.Emails.AccountConfirmationTemplate
  alias AuthToolkit.Emails.ConfirmationCodeTemplate
  alias AuthToolkit.Emails.ResetPasswordTemplate

  @impl true
  def send_account_confirmation(user, code) do
    html = AccountConfirmationTemplate.render(code: code)
    # Send email using your preferred email library
    send_email(user.email, "Confirm Your Account", html)
  end

  @impl true
  def send_confirmation_code(user, code) do
    html = ConfirmationCodeTemplate.render(code: code)
    send_email(user.email, "Your Confirmation Code", html)
  end

  @impl true
  def send_reset_password_code(user, code) do
    html = ResetPasswordTemplate.render(code: code)
    send_email(user.email, "Reset Your Password", html)
  end

  defp send_email(to, subject, html) do
    new()
    |> to(to)
    |> from(config(:from_email, "noreply@example.com"))
    |> subject(subject)
    |> html_body(html)
    |> mailer().deliver()
  end

  defp mailer do
    config(:mailer, AuthToolkit.Mailer)
  end

  defp config(key, default \\ nil) do
    Application.get_env(:auth_toolkit, __MODULE__, [])
    |> Keyword.get(key, default)
  end
end
