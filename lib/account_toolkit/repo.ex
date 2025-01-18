defmodule AccountToolkit.Repo do
  def get_repo do
    Application.get_env(:account_toolkit, :repo) ||
      raise "Referral Toolkit repo not configured. Add repo: YourRepo to the account_toolkit config"
  end
end
