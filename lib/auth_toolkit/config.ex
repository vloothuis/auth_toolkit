defmodule AuthToolkit.Config do
  @moduledoc false

  def route_action(user, action) do
    router =
      Application.get_env(:auth_toolkit, :action_router, fn _, _ ->
        "/"
      end)

    router.(user, action)
  end

  def endpoint do
    Application.get_env(:auth_toolkit, :endpoint)
  end

  def app_name do
    Application.get_env(:auth_toolkit, :app_name, "Test App")
  end

  def disclaimer_html do
    Application.get_env(:auth_toolkit, :disclaimer_html)
  end
end
