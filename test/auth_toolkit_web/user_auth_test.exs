defmodule AuthToolkitWeb.UserAuthTest do
  use AuthToolkitWeb.ConnCase, async: true

  import AuthToolkitFixtures

  alias AuthToolkitWeb.UserAuth

  setup %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> fetch_flash()

    %{conn: conn}
  end

  describe "require_authenticated_user/2" do
    test "redirects if user is not authenticated", %{conn: conn} do
      conn = UserAuth.require_authenticated_user(conn, [])
      assert conn.halted
      assert redirected_to(conn) == ~p"/auth/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You must log in"
    end

    test "stores return to path in session", %{conn: conn} do
      halted_conn = UserAuth.require_authenticated_user(%{conn | path_info: ["foo"], query_string: ""}, [])

      assert halted_conn.halted
      assert get_session(halted_conn, :user_return_to) == "/foo"
    end

    test "does not redirect if user is authenticated", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> assign(:current_user, user)
        |> UserAuth.require_authenticated_user([])

      refute conn.halted
      refute conn.status
    end
  end

  describe "require_confirmed_user/2" do
    test "redirects if user is not confirmed", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> assign(:current_user, user)
        |> UserAuth.require_confirmed_user([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/auth/confirm"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You must confirm your email"
    end

    test "does not redirect if user is confirmed", %{conn: conn} do
      user = user_fixture()
      confirmed_user = %{user | confirmed_at: DateTime.utc_now()}

      conn =
        conn
        |> assign(:current_user, confirmed_user)
        |> UserAuth.require_confirmed_user([])

      refute conn.halted
      refute conn.status
    end
  end
end
