defmodule AuthToolkitWeb.UserForgotPasswordLiveTest do
  use AuthToolkitWeb.ConnCase

  import AuthToolkitFixtures
  import Mox
  import Phoenix.LiveViewTest

  alias AuthToolkit.EmailBackend
  alias AuthToolkit.TestRepo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/auth/reset_password")

      assert html =~ "Forgot your password?"
      assert html =~ "Sign up"
      assert html =~ "sign in"
    end

    test "renders email page without sign up link on iOS", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/auth/reset_password?source=beepr.ios")

      refute html =~ "Sign up"
    end

    test "redirects if already logged in", %{conn: conn} do
      {:ok, user} = AuthToolkit.confirm_user(user_fixture())

      result =
        conn
        |> log_in_user(user)
        |> live(~p"/auth/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset flow" do
    setup do
      %{user: user_fixture()}
    end

    test "shows code entry after sending email", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/auth/reset_password")

      expect(EmailBackendMock, :send_reset_password_code, fn reset_user, _code ->
        assert user.email == reset_user.email
        {:ok, reset_user}
      end)

      lv
      |> form("#reset_password_form", user: %{"email" => user.email})
      |> render_submit()

      # Now we should see the code entry form
      assert render(lv) =~ "Enter the code sent to your email"
      assert render(lv) =~ "code_entry"
    end

    test "allows password reset with valid code", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/auth/reset_password")

      stub(EmailBackendMock, :send_reset_password_code, fn user, _code -> {:ok, user} end)

      lv
      |> form("#reset_password_form", user: %{"email" => user.email})
      |> render_submit()

      code = TestRepo.get_by!(AuthToolkit.UserConfirmationCode, user_id: user.id).code

      # Submit the code
      lv
      |> element("#code_entry")
      |> render_hook("check_code", %{"code" => code})

      # Now we should see the password reset form
      assert render(lv) =~ "New password"

      # Submit new password
      {:ok, conn} =
        lv
        |> form("#password_reset_form",
          user: %{
            "password" => "NewPassword123!",
            "password_confirmation" => "NewPassword123!"
          }
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/auth/log_in")

      assert conn.resp_body =~ "Password reset successfully"
    end

    test "shows error with invalid code", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/auth/reset_password")

      stub(EmailBackendMock, :send_reset_password_code, fn user, _code -> {:ok, user} end)

      lv
      |> form("#reset_password_form", user: %{"email" => user.email})
      |> render_submit()

      # Submit invalid code
      html =
        lv
        |> element("#code_entry")
        |> render_hook("check_code", %{"code" => "000000"})

      assert html =~ "Invalid or expired code"
    end
  end
end
