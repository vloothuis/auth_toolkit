defmodule AuthToolkitWeb.UserLoginLiveTest do
  use AuthToolkitWeb.ConnCase

  import AuthToolkitFixtures
  import Phoenix.LiveViewTest

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/auth/log_in")

      assert html =~ "Sign in"
      assert html =~ "Forgot your password?"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/auth/log_in")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "user login" do
    test "redirects if user login with valid credentials", %{conn: conn} do
      user = user_fixture(%{password: valid_user_password()})

      {:ok, lv, _html} = live(conn, ~p"/auth/log_in")

      form =
        form(lv, "#login_form", user: %{email: user.email, password: valid_user_password(), remember_me: true})

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/auth/confirm"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/auth/log_in")

      form =
        form(lv, "#login_form", user: %{email: "test@email.com", password: "123456", remember_me: true})

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"

      assert redirected_to(conn) == ~p"/auth/log_in"
    end

    test "clears session when logging in", %{conn: conn} do
      user = user_fixture(%{password: valid_user_password()})

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> put_session(:test_key, "test_value")

      assert get_session(conn, :test_key) == "test_value"

      {:ok, lv, _html} = live(conn, ~p"/auth/log_in")

      form =
        form(lv, "#login_form", user: %{email: user.email, password: valid_user_password(), remember_me: true})

      conn = submit_form(form, conn)

      assert get_session(conn, :test_key) == nil
      assert redirected_to(conn) == ~p"/auth/confirm"
    end

    test "keeps preserved session variables when logging in", %{conn: conn} do
      # The test router has a preserved session var configured
      user = user_fixture(%{password: valid_user_password()})

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> put_session(:keep_me, "preserved_value")
        |> put_session(:remove_me, "deleted_value")

      assert get_session(conn, :keep_me) == "preserved_value"
      assert get_session(conn, :remove_me) == "deleted_value"

      {:ok, lv, _html} = live(conn, ~p"/auth/log_in")

      form =
        form(lv, "#login_form", user: %{email: user.email, password: valid_user_password(), remember_me: true})

      conn = submit_form(form, conn)

      assert get_session(conn, :keep_me) == "preserved_value"
      assert get_session(conn, :remove_me) == nil
      assert redirected_to(conn) == ~p"/auth/confirm"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/log_in")

      assert {:error, {:live_redirect, %{kind: :push, to: ~p"/auth/sign_up"}}} ==
               lv
               |> element(~s|a:fl-contains("Sign up")|)
               |> render_click()
    end

    test "redirects to forgot password page when the Forgot Password button is clicked", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/auth/log_in")

      {:ok, conn} =
        lv
        |> element(~s{a:fl-contains('Forgot your password?')})
        |> render_click()
        |> follow_redirect(conn, ~p"/auth/reset_password")

      assert conn.resp_body =~ "Forgot your password?"
    end
  end
end
