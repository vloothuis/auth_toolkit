defmodule AuthToolkit.Migrations.V01 do
  @moduledoc false
  use Ecto.Migration

  def up(opts) do
    execute("CREATE EXTENSION IF NOT EXISTS citext", "")

    create table(:auth_toolkit_users, primary_key: [name: :id, type: :identity]) do
      add(:email, :citext, null: false)
      add(:hashed_password, :string, null: false)
      add(:confirmed_at, :timestamptz)
      timestamps()
    end

    create table(:auth_toolkit_users_tokens, primary_key: false) do
      add(:user_id, references(:auth_toolkit_users, on_delete: :delete_all, type: :bigint), null: false)
      add(:token, :binary, null: false, primary_key: true)
      add(:context, :string, null: false, primary_key: true)
      timestamps(updated_at: false)
    end

    create table(:auth_toolkit_user_confirmation_codes, primary_key: false) do
      add(:code, :text, null: false)

      add(:user_id, references(:auth_toolkit_users, on_delete: :delete_all, type: :bigint),
        null: false,
        primary_key: true
      )

      add(:expires_at, :timestamptz, null: false)

      constraint(:code_chk, check: "char_length(code) <= 99")
    end

    create(unique_index(:auth_toolkit_users, [:email]))
    create(index(:auth_toolkit_users_tokens, [:user_id]))
    create(unique_index(:auth_toolkit_users_tokens, [:context, :token]))
  end

  def down(_) do
    # Drop indexes
    drop(unique_index(:auth_toolkit_user_confirmation_codes, [:user_id]))
    drop(index(:auth_toolkit_users_tokens, [:user_id]))
    drop(unique_index(:auth_toolkit_users_tokens, [:context, :token]))
    drop(unique_index(:auth_toolkit_users, [:email]))

    # Drop tables
    drop(table(:auth_toolkit_user_confirmation_codes))
    drop(table(:auth_toolkit_users_tokens))
    drop(table(:auth_toolkit_users))

    # Check if citext is being used by other tables before dropping
    sql = """
    SELECT count(*)
    FROM pg_attribute a
    JOIN pg_class t ON a.attrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE a.atttypid = 'citext'::regtype::oid
    AND n.nspname = 'public'
    AND t.relname NOT IN ('auth_toolkit_codes');
    """

    %{rows: [[count]]} = repo().query!(sql)

    if count == 0 do
      execute("DROP EXTENSION IF EXISTS citext")
    end
  end
end
