defmodule AuthToolkitWeb.Plugs.RequireConfirmedUser do
  @moduledoc false
  import Phoenix.Controller
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    user = conn.assigns.current_user

    if user && user.confirmed_at do
      conn
    else
      conn
      |> put_flash(:info, "You must confirm your account before continuing.")
      |> redirect(to: "/auth/confirm")
      |> halt()
    end
  end
end
