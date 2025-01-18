defmodule AuthToolkit.TestUtils do
  @moduledoc false
  alias AuthToolkit.User

  def valid_password do
    "Hello world!"
  end

  def register_confirmed_user(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          email: "user_#{System.unique_integer()}@example.com",
          password: "Hello world!"
        },
        attrs
      )

    {:ok, user, _confirmation_code} = AuthToolkit.register_user(attrs, "127.0.0.1")
    {:ok, _} = AuthToolkit.confirm_user(user)
    user
  end

  def log_in_user(conn, %User{} = user) do
    token = AuthToolkit.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  def register_and_log_in_user(%{conn: conn}) do
    user = register_confirmed_user()
    conn = log_in_user(conn, user)
    {:ok, %{conn: conn, user: user}}
  end
end
