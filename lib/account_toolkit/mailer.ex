defmodule AccountToolkit.Mailer do
  @moduledoc false
  def deliver(email) do
    # FIXME: Use config to get the actual mailer and use it here
    {:ok, email}
  end
end
