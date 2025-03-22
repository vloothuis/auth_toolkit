defmodule AuthToolkit.DefaultEmailBackendTest do
  use ExUnit.Case, async: true

  import Swoosh.TestAssertions

  setup do
    user = %{email: "test@example.com"}
    code = "123456"
    {:ok, user: user, code: code}
  end

  describe "send_account_confirmation/2" do
    test "sends confirmation email", %{user: user, code: code} do
      AuthToolkit.DefaultEmailBackend.send_account_confirmation(user, code)

      assert_email_sent(
        subject: "Confirm Your Account",
        to: [{"", "test@example.com"}],
        html_body: ~r/#{code}/
      )
    end
  end

  describe "send_confirmation_code/2" do
    test "sends confirmation code email", %{user: user, code: code} do
      AuthToolkit.DefaultEmailBackend.send_confirmation_code(user, code)

      assert_email_sent(
        subject: "Your Confirmation Code",
        to: [{"", "test@example.com"}],
        html_body: ~r/#{code}/
      )
    end
  end

  describe "send_reset_password_code/2" do
    test "sends reset password email", %{user: user, code: code} do
      AuthToolkit.DefaultEmailBackend.send_reset_password_code(user, code)

      assert_email_sent(
        subject: "Reset Your Password",
        to: [{"", "test@example.com"}],
        html_body: ~r/#{code}/
      )
    end
  end
end
