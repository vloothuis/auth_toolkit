defmodule AuthToolkitWeb.UserEmailSettingsLive do
  @moduledoc false
  use AuthToolkitWeb, :live_view

  alias AuthToolkit.Emails

  def render(%{show_confirmation: true} = assigns) do
    ~H"""
    <.section_header>
      Confirm your new email
      <:subtitle>
        Please check your email for verification code sent to: <%= @new_email %>
      </:subtitle>
    </.section_header>

    <.form_box>
      <p class="text-center">Enter verification code</p>
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

  def render(assigns) do
    ~H"""
    <.section_header >
      Email Settings
      <:subtitle>Manage your account email address</:subtitle>
    </.section_header>

    <.form_box>
      <.simple_form
        for={@email_form}
        id="email_form"
        phx-submit="update_email"
        phx-change="validate_email"
      >
        <.input field={@email_form[:email]} type="email" label="Email" required />
        <.input
          field={@email_form[:current_password]}
          name="current_password"
          id="current_password_for_email"
          type="password"
          label="Current password"
          value={@email_form_current_password}
          required
        />
        <:actions>
          <.primary_button phx-disable-with="Changing...">Change Email</.primary_button>
        </:actions>
      </.simple_form>
    </.form_box>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = AuthToolkit.change_user_email(user)

    socket =
      socket
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:show_confirmation, false)
      |> assign(:new_email, nil)
      |> assign(:error, nil)
      |> assign(:email_sent, false)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> AuthToolkit.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case AuthToolkit.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        {:ok, confirmation_code} = AuthToolkit.create_confirmation_code(applied_user)
        Emails.send_confirmation_code(applied_user, confirmation_code.code)

        {:noreply,
         socket
         |> assign(:show_confirmation, true)
         |> assign(:new_email, user_params["email"])
         |> assign(:email_sent, true)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("check_code", %{"code" => <<code::binary-size(6)>>}, socket) do
    user = socket.assigns.current_user

    case AuthToolkit.confirm_email_change(user, code, socket.assigns.new_email) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Email changed successfully.")
         |> redirect(to: path(socket, ~p"/auth/account/settings/email"))}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Activation code is invalid or has expired.")}
    end
  end

  def handle_event("check_code", %{"code" => _code}, socket) do
    {:noreply, assign(socket, :error, nil)}
  end

  def handle_event("resend_code", _params, socket) do
    user = socket.assigns.current_user
    {:ok, confirmation_code} = AuthToolkit.create_confirmation_code(user)
    Emails.send_confirmation_code(user, confirmation_code.code)

    {:noreply,
     socket
     |> put_flash(:info, "Verification code has been resent.")
     |> assign(:email_sent, true)}
  end
end
