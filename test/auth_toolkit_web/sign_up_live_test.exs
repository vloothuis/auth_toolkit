defmodule AuthToolkitWeb.SignUpLiveTest do
  use AuthToolkitWeb.ConnCase

  import AuthToolkitFixtures
  import Mox
  import Phoenix.LiveViewTest

  alias AuthToolkit.EmailBackend

  setup :verify_on_exit!

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/auth/sign_up")

      assert html =~ "Register"
      assert html =~ "Sign in"
    end

    test "redirects if already logged in", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      result =
        conn
        |> live(~p"/auth/sign_up")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/sign_up")

      result =
        lv
        |> element("#sign_up_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "short"})

      assert result =~ "Register"
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 8 character"
    end
  end

  describe "register" do
    test "creates organisation with account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/sign_up")

      email = unique_user_email()

      expect(EmailBackendMock, :send_account_confirmation, fn user, _code ->
        assert user.email == email
        {:ok, user}
      end)

      form = form(lv, "#sign_up_form", user: valid_sign_up_attributes(email: email))
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/sign_up")

      assert {:error, {:redirect, %{to: "/auth/log_in"}}} =
               lv
               |> element(~s|a:fl-contains("Sign in")|)
               |> render_click()
    end
  end

  defp valid_sign_up_attributes(opts) do
    valid_user_attributes(opts)
  end
end
