defmodule AuthToolkitWeb.Routes do
  @moduledoc false

  defmacro routes(opts \\ []) do
    scope = Access.get(opts, :scope, "/auth")
    redirect_to_after_confirmation = Access.get(opts, :redirect_to_after_confirmation, "/")
    preserved_session_vars = opts |> Access.get(:preserved_session_vars, []) |> Enum.map(&to_string/1)

    quote do
      import AuthToolkitWeb.UserAuth
      import Phoenix.LiveView.Router

      forward("/auth_toolkit", Plug.Static, from: {:auth_toolkit, "priv/static"}, at: "/")

      pipeline :auth_toolkit_browser do
        plug(:accepts, ["html"])
        plug(:fetch_session)
        plug(:fetch_live_flash)
        plug(:put_root_layout, {AuthToolkitWeb.Layouts, :root})
        plug(:protect_from_forgery)
        plug(:put_secure_browser_headers)
        plug(:fetch_current_user)
      end

      scope unquote(scope), AuthToolkitWeb do
        pipe_through([:auth_toolkit_browser, :redirect_if_user_is_authenticated])

        live_session :auth_toolkit_redirect_if_user_is_authenticated,
          on_mount: [
            {AuthToolkitWeb.UserAuth, :redirect_if_user_is_authenticated}
          ] do
          live("/sign_up", SignUpLive, :show)

          live("/log_in", UserLoginLive, :new)
          live("/reset_password", UserForgotPasswordLive, :new)
        end

        post("/log_in", UserSessionController, :create,
          assigns: %{preserved_session_vars: unquote(preserved_session_vars)}
        )
      end

      scope unquote(scope), AuthToolkitWeb do
        pipe_through([:auth_toolkit_browser, :require_authenticated_user])

        live_session :auth_toolkit_require_authenticated_user,
          on_mount: [
            {AuthToolkitWeb.UserAuth, :ensure_authenticated}
          ],
          session: %{"redirect_to_after_confirmation" => unquote(redirect_to_after_confirmation)} do
          live("/settings/email", UserEmailSettingsLive, :edit)
          live("/settings/password", UserPasswordSettingsLive, :edit)

          live("/confirm", UserConfirmationLive, :index)
        end

        delete("/log_out", UserSessionController, :delete)
      end
    end
  end
end
