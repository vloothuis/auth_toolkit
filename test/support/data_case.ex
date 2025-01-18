defmodule AuthToolkit.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using _options do
    quote do
      import AuthToolkit.DataCase
      import Ecto
      import Ecto.Changeset
      import Ecto.Query

      setup do
        Application.put_env(:auth_toolkit, :repo, AuthToolkit.TestRepo)
      end
    end
  end

  setup tags do
    AuthToolkit.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(AuthToolkit.TestRepo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
