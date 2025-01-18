defmodule AuthToolkitWeb.Router do
  use AuthToolkitWeb, :router

  require AuthToolkitWeb.Routes

  AuthToolkitWeb.Routes.routes(scope: "/auth")

  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  scope "/dev" do
    # pipe_through(:browser)

    forward("/mailbox", Plug.Swoosh.MailboxPreview)
  end
end
