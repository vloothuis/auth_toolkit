defmodule AuthToolkitWeb.UserSessionControllerTest do
  use AuthToolkitWeb.ConnCase

  import AuthToolkitFixtures

  setup do
    %{user: user_fixture(), password: valid_user_password()}
  end

  describe "POST /auth/log_in with registered action" do
    test "logs the user in with valid credentials after registration", %{conn: conn, user: user, password: password} do
      params = %{
        "_action" => "registered",
        "user" => %{"email" => user.email, "password" => password}
      }

      conn = post(conn, ~p"/auth/log_in", params)
      assert get_session(conn, :user_token)
      assert get_flash(conn, :info) == "Account created successfully!"
      assert redirected_to(conn) == ~p"/auth/confirm"
    end

    test "returns error with invalid credentials", %{conn: conn} do
      params = %{
        "_action" => "registered",
        "user" => %{"email" => "invalid@example.com", "password" => "invalid"}
      }

      conn = post(conn, ~p"/auth/log_in", params)

      assert get_flash(conn, :error) == "Invalid email or password"
      assert get_flash(conn, :email) == "invalid@example.com"
      assert redirected_to(conn) == ~p"/auth/log_in"
      refute conn.assigns[:current_user]
    end
  end
end
