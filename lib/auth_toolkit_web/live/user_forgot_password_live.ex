defmodule AuthToolkitWeb.UserForgotPasswordLive do
  @moduledoc false
  use AuthToolkitWeb, :live_view

  alias Ecto.Changeset

  def render(%{step: :email} = assigns) do
    ~H"""
    <.section_header>
      Forgot your password?
      <:subtitle>We'll send a code to your email to reset your password</:subtitle>
    </.section_header>

    <.form_box>
      <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.submit_button phx-disable-with="Sending..." class="w-full">
            Send code
          </.submit_button>
        </:actions>
      </.simple_form>
    </.form_box>

    <p :if={@show_signup_link} class="login-text">
      <.inline_link href={path(@socket, ~p"/auth/sign_up")}>Sign up</.inline_link>
      for an account.
      Or
      <.inline_link href={path(@socket, ~p"/auth/log_in")}>sign in</.inline_link>
      with your password.
    </p>
    """
  end

  def render(%{step: :code} = assigns) do
    ~H"""
    <.section_header>
      Enter verification code
      <:subtitle>Enter the code sent to your email: <%= @email %></:subtitle>
    </.section_header>

    <.form_box>
      <div
        phx-update="ignore"
        phx-hook="CodeEntry"
        data-phx-event="check_code"
        id="code_entry"
        class="mb-4 text-center"
      >
      </div>
      <.error :if={@error}><%= @error %></.error>
      <hr class="mt-12" />
      <p class="text-sm text-center">
        Didn't receive the code?
        <span class="whitespace-nowrap">
          Check your spam folder or
          <.inline_link phx-click="resend_code">resend code</.inline_link>
        </span>
      </p>
    </.form_box>
    """
  end

  def render(%{step: :password} = assigns) do
    ~H"""
    <.section_header>
      Reset Password
    </.section_header>
    <.form_box>
      <.simple_form
        for={@form}
        id="password_reset_form"
        phx-submit="reset_password"
        phx-change="validate_password"
      >
        <.error :if={@form.errors != []}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input
          field={@form[:password]}
          type="password"
          placeholder="New password"
          required
          phx-debounce="2000"
        />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          placeholder="Confirm new password"
          required
          phx-debounce="2000"
        />
        <:actions>
          <.submit_button phx-disable-with="Resetting..." class="w-full">
            Reset Password
          </.submit_button>
        </:actions>
      </.simple_form>
    </.form_box>
    """
  end

  def mount(params, _session, socket) do
    form =
      %{}
      |> get_changeset()
      |> to_form()

    {:ok,
     assign(socket,
       form: form,
       step: :email,
       error: nil,
       email: nil,
       show_signup_link: Map.get(params, "source") != "beepr.ios"
     )}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    changeset = get_changeset(%{"email" => email})

    case Changeset.apply_action(changeset, :validate) do
      {:ok, _} ->
        user = AuthToolkit.get_user_by_email(email)

        if user do
          {:ok, code} = AuthToolkit.create_confirmation_code(user)
          {:ok, _} = AuthToolkit.Emails.send_reset_password_code(user, code.code)
        end

        {:noreply,
         socket
         |> put_flash(:info, "If your email is in our system, you will receive a code shortly")
         |> assign(step: :code, email: email, user: user)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("check_code", _, %{assigns: %{user: nil}} = socket) do
    {:noreply, assign(socket, error: "Invalid or expired code")}
  end

  def handle_event("check_code", %{"code" => code}, %{assigns: %{user: user}} = socket) do
    case AuthToolkit.validate_code(user, code) do
      :ok ->
        changeset = AuthToolkit.change_user_password(user)
        {:noreply, assign(socket, step: :password, user: user, form: to_form(changeset))}

      _ ->
        {:noreply, assign(socket, error: "Invalid or expired code")}
    end
  end

  def handle_event("reset_password", %{"user" => params}, socket) do
    case AuthToolkit.reset_user_password(socket.assigns.user, params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: path(socket, ~p"/auth/log_in"))}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("validate_password", %{"user" => params}, socket) do
    changeset =
      socket.assigns.user
      |> AuthToolkit.change_user_password(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("resend_code", _, socket) do
    if user = AuthToolkit.get_user_by_email(socket.assigns.email) do
      {:ok, code} = AuthToolkit.create_confirmation_code(user)
      :ok = AuthToolkit.Emails.send_reset_password_code(user, code.code)
    end

    {:noreply, put_flash(socket, :info, "If your email is in our system, you will receive a new code shortly")}
  end

  defp get_changeset(params) do
    %AuthToolkit.User{}
    |> Changeset.cast(params, [:email])
    |> AuthToolkit.Validation.validate_email(validate_email: false)
  end
end
