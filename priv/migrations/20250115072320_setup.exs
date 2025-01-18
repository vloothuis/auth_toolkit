defmodule AuthToolkit.TestRepo.Migrations.Setup do
  @moduledoc false
  use Ecto.Migration

  def change do
    AuthToolkit.Migrations.up()
  end
end
