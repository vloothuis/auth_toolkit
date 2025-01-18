defmodule AccountToolkit.Migrations.V01 do
  @moduledoc false
  use Ecto.Migration

  def up(opts) do
    id_type = Access.get(opts, :id_type, :identity)
    execute("CREATE EXTENSION IF NOT EXISTS citext", "")

    create table(:account_toolkit_users, primary_key: [name: :id, type: id_type]) do
      add(:email, :citext, null: false)
      add(:name, :string, null: false)
      add(:hashed_password, :string, null: false)
      add(:confirmed_at, :timestamptz)
      timestamps()
    end

    create table(:account_toolkit_users_tokens) do
      add(:user_id, references(:account_toolkit_users, on_delete: :delete_all, type: id_type), null: false)
      add(:token, :binary, null: false)
      add(:context, :string, null: false)
      add(:sent_to, :string)
      timestamps(updated_at: false)
    end

    create table(:account_toolkit_user_confirmation_codes, primary_key: [name: :user_id, type: id_type]) do
      add(:code, :text, null: false)
      # add(:user_id, references(:account_toolkit_users, on_delete: :delete_all, type: id_type), null: false)

      timestamps()

      constraint(:code_chk, check: "char_length(code) <= 99")
    end

    create(unique_index(:account_toolkit_user_confirmation_codes, [:user_id]))
    create(unique_index(:account_toolkit_users, [:email]))
    create(index(:account_toolkit_users_tokens, [:user_id]))
    create(unique_index(:account_toolkit_users_tokens, [:context, :token]))
  end

  def down(_) do
    # Drop indexes
    drop(unique_index(:account_toolkit_user_confirmation_codes, [:user_id]))
    drop(index(:account_toolkit_users_tokens, [:user_id]))
    drop(unique_index(:account_toolkit_users_tokens, [:context, :token]))
    drop(unique_index(:account_toolkit_users, [:email]))

    # Drop tables
    drop(table(:account_toolkit_user_confirmation_codes))
    drop(table(:account_toolkit_users_tokens))
    drop(table(:account_toolkit_users))

    # Check if citext is being used by other tables before dropping
    sql = """
    SELECT count(*)
    FROM pg_attribute a
    JOIN pg_class t ON a.attrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE a.atttypid = 'citext'::regtype::oid
    AND n.nspname = 'public'
    AND t.relname NOT IN ('account_toolkit_codes');
    """

    %{rows: [[count]]} = repo().query!(sql)

    if count == 0 do
      execute("DROP EXTENSION IF EXISTS citext")
    end
  end
end
