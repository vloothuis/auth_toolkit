defmodule AuthToolkitWeb.UserConfirmationLive do
  @moduledoc false
  use AuthToolkitWeb, :live_view

  alias AuthToolkit.Emails

  def render(%{live_action: :index} = assigns) do
    ~H"""
    <.section_header>
      We need to verify your email
      <:subtitle>
        Please check your email for verification code sent to: <%= @email %>
      </:subtitle>
    </.section_header>

    <p :if={@email_sent} >
    A new code has been sent.
    </p>

    <.form_box>
      <p class=" text-center">Enter verification code</p>
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

  def mount(_, session, socket) do
    form = to_form(%{"code" => ""}, as: "confirmation")
    email = socket.assigns.current_user.email

    {:ok,
     assign(socket,
       form: form,
       error: nil,
       email: email,
       email_sent: false,
       redirect_to_after_confirmation: session["redirect_to_after_confirmation"] || "/"
     ), temporary_assigns: [form: nil]}
  end

  def handle_event("check_code", %{"code" => <<code::binary-size(6)>>}, socket) do
    user = socket.assigns.current_user

    case AuthToolkit.confirm_user(user, String.upcase(code)) do
      {:ok, _} ->
        {:noreply, redirect(socket, to: socket.assigns.redirect_to_after_confirmation)}

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

    {:noreply, assign(socket, :email_sent, true)}
  end
end
