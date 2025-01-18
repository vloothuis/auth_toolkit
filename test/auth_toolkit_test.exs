defmodule AuthToolkitTest do
  use AuthToolkit.DataCase

  import AuthToolkitFixtures
  import Mock
  import Mox

  alias AuthToolkit.TestRepo
  alias AuthToolkit.User
  alias AuthToolkit.UserConfirmationCode
  alias AuthToolkit.UserToken

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute AuthToolkit.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = AuthToolkit.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute AuthToolkit.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute AuthToolkit.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               AuthToolkit.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        AuthToolkit.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = AuthToolkit.get_user!(user.id)
    end
  end

  describe "get_user_by_api_token/1" do
    test "returns nil if invalid" do
      refute AuthToolkit.get_user_by_api_token(Base.encode64("bla"))
    end

    test "returns nil when not base64" do
      refute AuthToolkit.get_user_by_api_token("@")
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               AuthToolkit.get_user_by_api_token(AuthToolkit.generate_user_api_token(user))
    end
  end

  describe "register_user/2" do
    test "requires email and password to be set" do
      {:error, changeset} = AuthToolkit.register_user(%{}, {127, 0, 0, 1})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = AuthToolkit.register_user(%{email: "not valid", password: "short"}, {127, 0, 0, 1})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: [
                 "at least one digit or punctuation character",
                 "at least one upper case character",
                 "should be at least 8 character(s)"
               ]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = AuthToolkit.register_user(%{email: too_long, password: too_long}, {127, 0, 0, 1})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "registers users with a hashed password and confirmation code" do
      email = unique_user_email()
      {:ok, user, confirmation_code} = AuthToolkit.register_user(valid_user_attributes(email: email), {127, 0, 0, 1})
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
      assert confirmation_code.user_id == user.id
      assert is_binary(confirmation_code.code)
    end

    test "rate limits registration attempts" do
      old_rate_limiter = Application.get_env(:auth_toolkit, :rate_limiter)
      Application.put_env(:auth_toolkit, :rate_limiter, RateLimiterMock)
      on_exit(fn -> Application.put_env(:auth_toolkit, :rate_limiter, old_rate_limiter) end)

      email = unique_user_email()
      attrs = valid_user_attributes(email: email)
      ip = {127, 0, 0, 1}

      expect(RateLimiterMock, :check_rate, fn
        "register", "127.0.0.1" -> {:deny, 10}
      end)

      assert {:error, :rate_limit} = AuthToolkit.register_user(attrs, ip)
    end
  end

  describe "create_confirmation_code/1" do
    test "creates a user code" do
      user = user_fixture()
      assert {:ok, %UserConfirmationCode{}} = AuthToolkit.create_confirmation_code(user)
    end

    test "creates a new user code when there was one already" do
      user = user_fixture()
      {:ok, first_code} = AuthToolkit.create_confirmation_code(user)
      {:ok, second_code} = AuthToolkit.create_confirmation_code(user)
      assert first_code.code != second_code.code
    end
  end

  describe "confirm_user/1" do
    test "confirm with valid code" do
      user = user_fixture()
      {:ok, %{code: code}} = AuthToolkit.create_confirmation_code(user)
      assert {:ok, user} = AuthToolkit.confirm_user(user, code)
      assert user.confirmed_at != nil
    end

    test "does not confirm with expired code" do
      user = user_fixture()
      {:ok, code_record} = AuthToolkit.create_confirmation_code(user)
      old_time = DateTime.add(DateTime.utc_now(), -30 * 60, :second)

      {1, nil} =
        TestRepo.update_all(
          from(c in AuthToolkit.UserConfirmationCode, where: c.user_id == ^user.id),
          set: [expires_at: old_time]
        )

      assert {:error, :expired} = AuthToolkit.confirm_user(user, code_record.code)
      assert user.confirmed_at == nil
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = AuthToolkit.change_user_registration(%User{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()

      changeset =
        AuthToolkit.change_user_registration(
          %User{},
          valid_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = AuthToolkit.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = AuthToolkit.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        AuthToolkit.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        AuthToolkit.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        AuthToolkit.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = AuthToolkit.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert AuthToolkit.get_user!(user.id).email != email
    end
  end

  describe "confirm_email_change/3" do
    setup do
      %{user: user_fixture()}
    end

    test "confirms email change with valid code", %{user: user} do
      new_email = unique_user_email()
      {:ok, confirmation} = AuthToolkit.create_confirmation_code(user)

      assert {:ok, user} = AuthToolkit.confirm_email_change(user, confirmation.code, new_email)
      changed_user = AuthToolkit.get_user!(user.id)
      assert changed_user.email == new_email
      assert changed_user.confirmed_at
    end

    test "does not confirm with invalid code", %{user: user} do
      new_email = unique_user_email()
      {:ok, user} = AuthToolkit.apply_user_email(user, valid_user_password(), %{email: new_email})

      assert {:error, :invalid_code} = AuthToolkit.confirm_email_change(user, "invalid", new_email)
      assert AuthToolkit.get_user!(user.id).email != new_email
    end

    test "does not confirm with expired code", %{user: user} do
      new_email = unique_user_email()
      {:ok, user} = AuthToolkit.apply_user_email(user, valid_user_password(), %{email: new_email})
      {:ok, confirmation} = AuthToolkit.create_confirmation_code(user)

      old_time = DateTime.add(DateTime.utc_now(), -30 * 60, :second)

      {1, nil} =
        TestRepo.update_all(
          from(c in AuthToolkit.UserConfirmationCode, where: c.user_id == ^user.id),
          set: [expires_at: old_time]
        )

      assert {:error, :expired} = AuthToolkit.confirm_email_change(user, confirmation.code, new_email)
      assert AuthToolkit.get_user!(user.id).email != new_email
    end
  end

  describe "delete_user/1" do
    setup do
      user = user_fixture()

      %{user: user}
    end

    test "deleting a user sets the deleted at", %{user: user} do
      assert {:ok, _} = AuthToolkit.delete_user(user)
      assert AuthToolkit.get_user_by_email(user.email) == nil
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = AuthToolkit.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        AuthToolkit.change_user_password(%User{}, %{
          "password" => valid_user_password() <> "new"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == valid_user_password() <> "new"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        AuthToolkit.update_user_password(user, valid_user_password(), %{
          password: "short",
          password_confirmation: "another"
        })

      assert %{
               password: [
                 "at least one digit or punctuation character",
                 "at least one upper case character",
                 "should be at least 8 character(s)"
               ],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        AuthToolkit.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        AuthToolkit.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        AuthToolkit.update_user_password(user, valid_user_password(), %{
          password: valid_user_password() <> "new"
        })

      assert is_nil(user.password)
      assert AuthToolkit.get_user_by_email_and_password(user.email, valid_user_password() <> "new")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = AuthToolkit.generate_user_session_token(user)

      {:ok, _} =
        AuthToolkit.update_user_password(user, valid_user_password(), %{
          password: valid_user_password() <> "new"
        })

      refute TestRepo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = AuthToolkit.generate_user_session_token(user)
      assert user_token = TestRepo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        TestRepo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = AuthToolkit.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = AuthToolkit.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute AuthToolkit.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {_, nil} =
        TestRepo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      refute AuthToolkit.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = AuthToolkit.generate_user_session_token(user)
      assert AuthToolkit.delete_user_session_token(token) == :ok
      refute AuthToolkit.get_user_by_session_token(token)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        AuthToolkit.reset_user_password(user, %{
          password: "short",
          password_confirmation: "small"
        })

      assert %{
               password: [
                 "at least one digit or punctuation character",
                 "at least one upper case character",
                 "should be at least 8 character(s)"
               ],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = AuthToolkit.reset_user_password(user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} =
        AuthToolkit.reset_user_password(user, %{password: valid_user_password() <> "new"})

      assert is_nil(updated_user.password)
      assert AuthToolkit.get_user_by_email_and_password(user.email, valid_user_password() <> "new")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = AuthToolkit.generate_user_session_token(user)
      {:ok, _} = AuthToolkit.reset_user_password(user, %{password: valid_user_password() <> "new"})
      refute TestRepo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
