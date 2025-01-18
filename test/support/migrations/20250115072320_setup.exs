defmodule AccountToolkit.TestRepo.Migrations.Setup do
  @moduledoc false
  use Ecto.Migration

  def change do
    AccountToolkit.Migrations.up()
  end
end
