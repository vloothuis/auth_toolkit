defmodule AccountToolkitTest do
  use AccountToolkit.DataCase

  import AccountToolkitFixtures

  alias AccountToolkit.TestRepo
  alias AccountToolkit.User
  alias AccountToolkit.UserConfirmationCode
  alias AccountToolkit.UserToken

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute AccountToolkit.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = AccountToolkit.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute AccountToolkit.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute AccountToolkit.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               AccountToolkit.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        AccountToolkit.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = AccountToolkit.get_user!(user.id)
    end
  end

  describe "get_user_by_api_token/1" do
    test "returns nil if invalid" do
      refute AccountToolkit.get_user_by_api_token(Base.encode64("bla"))
    end

    test "returns nil when not base64" do
      refute AccountToolkit.get_user_by_api_token("@")
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               AccountToolkit.get_user_by_api_token(AccountToolkit.generate_user_api_token(user))
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = AccountToolkit.register_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = AccountToolkit.register_user(%{email: "not valid", password: "short"})

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
      {:error, changeset} = AccountToolkit.register_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    # test "validates email uniqueness" do
    #   %{email: email} = user_fixture()
    #   {:error, changeset} = AccountToolkit.register_user(%{email: email})
    #   assert "has already been taken" in errors_on(changeset).email

    #   # Now try with the upper cased email too, to check that email case is ignored.
    #   {:error, changeset} = AccountToolkit.register_user(%{email: String.upcase(email)})
    #   assert "has already been taken" in errors_on(changeset).email
    # end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = AccountToolkit.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "create_confirmation_code/1" do
    test "creates a user code" do
      user = user_fixture()
      assert {:ok, %UserConfirmationCode{}} = AccountToolkit.create_confirmation_code(user)
    end

    test "creates a new user code when there was one already" do
      user = user_fixture()
      {:ok, first_code} = AccountToolkit.create_confirmation_code(user)
      {:ok, second_code} = AccountToolkit.create_confirmation_code(user)
      assert first_code.code != second_code.code
    end
  end

  describe "confirm_user/1" do
    test "confirm with valid code" do
      user = user_fixture()
      {:ok, %{code: code}} = AccountToolkit.create_confirmation_code(user)
      assert {:ok, user} = AccountToolkit.confirm_user(user, code)
      assert user.confirmed_at != nil
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = AccountToolkit.change_user_registration(%User{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()

      changeset =
        AccountToolkit.change_user_registration(
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
      assert %Ecto.Changeset{} = changeset = AccountToolkit.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = AccountToolkit.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        AccountToolkit.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        AccountToolkit.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    # test "validates email uniqueness", %{user: user} do
    #   %{email: email} = user_fixture()
    #   password = valid_user_password()

    #   {:error, changeset} = AccountToolkit.apply_user_email(user, password, %{email: email})

    #   assert "has already been taken" in errors_on(changeset).email
    # end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        AccountToolkit.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = AccountToolkit.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert AccountToolkit.get_user!(user.id).email != email
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          AccountToolkit.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)

      assert user_token =
               TestRepo.get_by(UserToken, [token: :crypto.hash(:sha256, token)], skip_org_id: true)

      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          AccountToolkit.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert AccountToolkit.update_user_email(user, token) == :ok
      changed_user = TestRepo.get!(User, user.id, skip_org_id: true)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute TestRepo.get_by(UserToken, [user_id: user.id], skip_org_id: true)
    end

    test "does not update email with invalid token", %{user: user} do
      assert AccountToolkit.update_user_email(user, "oops") == :error
      assert TestRepo.get!(User, user.id, skip_org_id: true).email == user.email
      assert TestRepo.get_by(UserToken, [user_id: user.id], skip_org_id: true)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert AccountToolkit.update_user_email(%{user | email: "current@example.com"}, token) == :error
      assert TestRepo.get!(User, user.id, skip_org_id: true).email == user.email
      assert TestRepo.get_by(UserToken, [user_id: user.id], skip_org_id: true)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} =
        TestRepo.update_all(UserToken, [set: [inserted_at: ~N[2020-01-01 00:00:00]]], skip_org_id: true)

      assert AccountToolkit.update_user_email(user, token) == :error
      assert TestRepo.get!(User, user.id, skip_org_id: true).email == user.email
      assert TestRepo.get_by(UserToken, [user_id: user.id], skip_org_id: true)
    end
  end

  describe "delete_user/1" do
    setup do
      user = user_fixture()

      %{user: user}
    end

    test "deleting a user sets the deleted at", %{user: user} do
      assert {:ok, _} = AccountToolkit.delete_user(user)
      assert AccountToolkit.get_user_by_email(user.email) == nil
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = AccountToolkit.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        AccountToolkit.change_user_password(%User{}, %{
          "password" => valid_user_password() <> "new"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == valid_user_password() <> "new"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_profile/2" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "updates fields when given valid data", %{user: user} do
      name = user.name <> " new"
      assert {:ok, changed_user} = AccountToolkit.update_user_profile(user, %{"name" => name})
      assert changed_user.name == name
    end
  end

  describe "change_user_profile/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = AccountToolkit.change_user_profile(%User{})
      assert changeset.required == [:name]
    end

    test "allows fields to be set" do
      changeset =
        AccountToolkit.change_user_profile(%User{}, %{
          "name" => "Lorem ipsum"
        })

      assert changeset.valid?
      assert get_change(changeset, :name) == "Lorem ipsum"
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        AccountToolkit.update_user_password(user, valid_user_password(), %{
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
        AccountToolkit.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        AccountToolkit.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        AccountToolkit.update_user_password(user, valid_user_password(), %{
          password: valid_user_password() <> "new"
        })

      assert is_nil(user.password)
      assert AccountToolkit.get_user_by_email_and_password(user.email, valid_user_password() <> "new")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = AccountToolkit.generate_user_session_token(user)

      {:ok, _} =
        AccountToolkit.update_user_password(user, valid_user_password(), %{
          password: valid_user_password() <> "new"
        })

      refute TestRepo.get_by(UserToken, [user_id: user.id], skip_org_id: true)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = AccountToolkit.generate_user_session_token(user)
      assert user_token = TestRepo.get_by(UserToken, [token: token], skip_org_id: true)
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
      token = AccountToolkit.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = AccountToolkit.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute AccountToolkit.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} =
        TestRepo.update_all(UserToken, [set: [inserted_at: ~N[2020-01-01 00:00:00]]], skip_org_id: true)

      refute AccountToolkit.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = AccountToolkit.generate_user_session_token(user)
      assert AccountToolkit.delete_user_session_token(token) == :ok
      refute AccountToolkit.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          AccountToolkit.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)

      assert user_token =
               TestRepo.get_by(UserToken, [token: :crypto.hash(:sha256, token)], skip_org_id: true)

      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          AccountToolkit.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)

      assert user_token =
               TestRepo.get_by(UserToken, [token: :crypto.hash(:sha256, token)], skip_org_id: true)

      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          AccountToolkit.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = AccountToolkit.get_user_by_reset_password_token(token)
      assert TestRepo.get_by(UserToken, [user_id: id], skip_org_id: true)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute AccountToolkit.get_user_by_reset_password_token("oops")
      assert TestRepo.get_by(UserToken, [user_id: user.id], skip_org_id: true)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} =
        TestRepo.update_all(UserToken, [set: [inserted_at: ~N[2020-01-01 00:00:00]]], skip_org_id: true)

      refute AccountToolkit.get_user_by_reset_password_token(token)
      assert TestRepo.get_by(UserToken, [user_id: user.id], skip_org_id: true)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        AccountToolkit.reset_user_password(user, %{
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
      {:error, changeset} = AccountToolkit.reset_user_password(user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} =
        AccountToolkit.reset_user_password(user, %{password: valid_user_password() <> "new"})

      assert is_nil(updated_user.password)
      assert AccountToolkit.get_user_by_email_and_password(user.email, valid_user_password() <> "new")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = AccountToolkit.generate_user_session_token(user)
      {:ok, _} = AccountToolkit.reset_user_password(user, %{password: valid_user_password() <> "new"})
      refute TestRepo.get_by(UserToken, [user_id: user.id], skip_org_id: true)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
