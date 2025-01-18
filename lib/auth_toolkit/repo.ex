defmodule AuthToolkit.Repo do
  def get_repo do
    Application.get_env(:auth_toolkit, :repo) ||
      raise "Referral Toolkit repo not configured. Add repo: YourRepo to the auth_toolkit config"
  end
end
