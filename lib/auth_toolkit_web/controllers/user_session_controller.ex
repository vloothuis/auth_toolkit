defmodule AuthToolkitWeb.UserSessionController do
  use AuthToolkitWeb, :controller

  alias AuthToolkit.RateLimiter
  alias AuthToolkitWeb.UserAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, path(conn, ~p"/auth/settings"))
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    case RateLimiter.check_rate("login", email) do
      {:allow, _count} ->
        if user = AuthToolkit.get_user_by_email_and_password(email, password) do
          conn
          |> put_flash(:info, info)
          |> UserAuth.log_in_user(user, user_params)
        else
          invalid_credentials(conn, email)
        end

      {:deny, _limit} ->
        conn
        |> put_flash(:error, "Too many login attempts. Please try again later.")
        |> redirect(to: path(conn, ~p"/auth/log_in"))
    end
  end

  defp create(conn, %{"registration_data" => registration_data}, info) when is_map(registration_data) do
    create(conn, %{"user" => registration_data}, info)
  end

  defp create(conn, %{"accept_invite" => accept_invite}, info) when is_map(accept_invite) do
    create(conn, %{"user" => accept_invite}, info)
  end

  defp create(conn, _params, _info) do
    invalid_credentials(conn)
  end

  defp invalid_credentials(conn, email \\ nil) do
    conn
    |> put_flash(:error, "Invalid email or password")
    |> maybe_put_email(email)
    |> redirect(to: path(conn, ~p"/auth/log_in"))
  end

  defp maybe_put_email(conn, nil), do: conn
  defp maybe_put_email(conn, email), do: put_flash(conn, :email, String.slice(email, 0, 160))

  @spec delete(Plug.Conn.t(), any) :: Plug.Conn.t()
  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
