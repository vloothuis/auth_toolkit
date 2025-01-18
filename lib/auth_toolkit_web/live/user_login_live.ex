defmodule AuthToolkitWeb.UserLoginLive do
  @moduledoc false
  use AuthToolkitWeb, :live_view

  alias AuthToolkit.Config

  def render(assigns) do
    ~H"""
    <.section_header>
      Login to {Config.app_name}
      <:subtitle>
        Don't have an account?
        <.inline_link navigate={path(@socket, ~p"/auth/sign_up")}>
          Sign up
        </.inline_link>
        for an account now.
      </:subtitle>
    </.section_header>

    <.form_box>
      <.simple_form for={@form} id="login_form" action={path(@socket, ~p"/auth/log_in")} phx-update="ignore">
        <.error :if={@error}><%= @error %></.error>

        <.input field={@form[:email]} label="Email" type="email" placeholder="Email" required autocomplete="email" />
        <.input
          field={@form[:password]}
          label="Password"
          type="password"
          placeholder="Password"
          required
          autocomplete="current-password"
        />
        <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" checked />
        <:actions>
          <.submit_button phx-disable-with="Signing in..." class="w-full">
            Sign in <span aria-hidden="true">→</span>
          </.submit_button>
        </:actions>
      </.simple_form>
    </.form_box>

    <p class="login-text">
    <.inline_link href={path(@socket, ~p"/auth/reset_password")}>
      Forgot your password?
    </.inline_link>
    </p>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    error = Phoenix.Flash.get(socket.assigns.flash, :error)

    socket = if error, do: clear_flash(socket), else: socket

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, error: error), temporary_assigns: [form: form]}
  end
end
