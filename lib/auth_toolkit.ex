defmodule AuthToolkit do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false

  alias AuthToolkit.Codes
  alias AuthToolkit.RateLimiter
  alias AuthToolkit.Repo
  alias AuthToolkit.User
  alias AuthToolkit.UserConfirmationCode
  alias AuthToolkit.UserToken

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_repo().get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password) when is_binary(email) and is_binary(password) do
    user = Repo.get_repo().get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get_repo().get!(User, id)

  def delete_user(%User{} = user) do
    Repo.get_repo().delete(user)
  end

  @doc """
  Registers a new user with rate limiting and confirmation code creation.
  Takes a map of user attributes and the remote IP address for rate limiting.

  Returns:
  - `{:ok, user, confirmation_code}` if registration is successful
  - `{:error, :rate_limit}` if too many attempts from the IP
  - `{:error, changeset}` if validation fails
  """
  def register_user(user_data, remote_ip) do
    with {:allow, _count} <- RateLimiter.check_rate("register", format_ip(remote_ip)),
         {:ok, user} <- create_user(user_data),
         {:ok, confirmation_code} <- create_confirmation_code(user) do
      {:ok, user, confirmation_code}
    else
      {:deny, _limit} -> {:error, :rate_limit}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
    end
  end

  defp create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.get_repo().insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: true)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using a confirmation code.
  Takes the user, the code, and the new email that was previously applied.
  Returns :ok on success or an error tuple.
  """
  def confirm_email_change(user, code, new_email) do
    case validate_code(user, code) do
      :ok ->
        changeset =
          user
          |> User.email_changeset(%{email: new_email})
          |> User.confirm_changeset()

        Repo.get_repo().update(changeset)

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :invalid_code}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.get_repo().transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.get_repo().insert!(user_token)
    token
  end

  def generate_user_api_token(user) do
    Base.encode64(generate_user_session_token(user), padding: false)
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.get_repo().one(query)
  end

  def get_user_by_api_token(token) do
    case Base.decode64(token, padding: false) do
      {:ok, token} -> get_user_by_session_token(token)
      _ -> nil
    end
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.get_repo().delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  def delete_user_api_token(token) do
    token |> Base.decode64!(padding: false) |> delete_user_session_token()
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.get_repo().one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.get_repo().transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  def create_confirmation_code(user) do
    code = Codes.random_code()

    Repo.get_repo().insert(
      %UserConfirmationCode{
        user_id: user.id,
        code: code,
        expires_at: UserConfirmationCode.expires_at()
      },
      on_conflict: :replace_all,
      conflict_target: [:user_id]
    )
  end

  def validate_code(user, code) do
    query = from(ac in UserConfirmationCode, where: ac.code == ^code and ac.user_id == ^user.id)

    case Repo.get_repo().one(query) do
      %UserConfirmationCode{} = code_record ->
        Repo.get_repo().delete(code_record)

        if UserConfirmationCode.expired?(code_record) do
          {:error, :expired}
        else
          :ok
        end

      nil ->
        {:error, :invalid_code}
    end
  end

  def confirm_user(user, code) do
    with :ok <- validate_code(user, code) do
      confirm_user(user)
    end
  end

  def confirm_user(user) do
    Repo.get_repo().update(User.confirm_changeset(user))
  end

  def format_ip(ip) when is_binary(ip), do: ip
  def format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  def format_ip({a, b, c, d, e, f, g, h}), do: "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
end
