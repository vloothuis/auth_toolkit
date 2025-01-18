defmodule AuthToolkitWeb.SignUpLive do
  @moduledoc false
  use AuthToolkitWeb, :live_view

  import AuthToolkitWeb.Components

  alias AuthToolkit.Config
  alias AuthToolkit.EmailBackend
  alias AuthToolkit.User
  alias Phoenix.HTML.FormField

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(socket,
       page_title: "Listing App configuration",
       user: %User{}
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.section_header>
      Create an account
    </.section_header>


    <.form_box>
      <.simple_form
        for={@form}
        id="sign_up_form"
        phx-throttle
        phx-change="validate"
        phx-submit="register"
        phx-trigger-action={@trigger_submit}
        action={path(@socket, ~p"/auth/log_in?return_to=confirm&_action=registered")}
        method="post"
        as={:user}
      >
        <.input
          field={@form[:email]}
          type="email"
          placeholder="Your email (e.g. name@company.com)"
          required=""
          autocomplete="email"
        />
        <.input
          field={@form[:password]}
          type="password"
          placeholder="Password"
          required=""
          autocomplete="new-password"
          phx-debounce="2000"
        />
        <p class="terms-text" :if={Config.disclaimer_html()}>
          {raw Config.disclaimer_html()}
        </p>
        <:actions>
          <.submit_button phx-disable-with="Saving...">Register</.submit_button>
        </:actions>
      </.simple_form>
    </.form_box>
    <div>
      <p class="login-text">
        Already have an account?
        <.inline_link href={path(@socket, ~p"/auth/log_in")}>
          Sign in
        </.inline_link>
      </p>
    </div>
    """
  end

  attr(:id, :any, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:value, :any)

  attr(:field, FormField, doc: "a form field struct retrieved from the form, for example: @form[:email]")

  attr(:errors, :list, default: [])
  attr(:checked, :boolean, doc: "the checked flag for checkbox inputs")
  attr(:prompt, :string, default: nil, doc: "the prompt for select inputs")
  attr(:options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2")
  attr(:multiple, :boolean, default: false, doc: "the multiple flag for select inputs")

  attr(:rest, :global, include: ~w(autocomplete cols disabled form list max maxlength min minlength
                  pattern placeholder readonly required rows size step))

  slot(:inner_block, required: true)

  def checkbox(%{field: %FormField{} = field} = assigns) do
    checkbox(prepare_input_assigns(assigns, field))
  end

  def checkbox(%{value: value} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn -> Phoenix.HTML.Form.normalize_value("checkbox", value) end)

    ~H"""
    <div phx-feedback-for={@name}>
      <label class="checkbox-label">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="checkbox-input"
          {@rest}
        />
        <%= render_slot(@inner_block) %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    changeset = AuthToolkit.change_user_registration(%User{})
    peer_data = get_connect_info(socket, :peer_data)

    socket =
      assign(socket,
        user: %User{},
        form: to_form(changeset),
        trigger_submit: false,
        remote_address: peer_data.address
      )

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("validate", %{"user" => user}, socket) do
    changeset =
      socket.assigns.user
      |> AuthToolkit.change_user_registration(user)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("register", %{"user" => user_data}, socket) do
    with {:ok, _} <-
           %User{}
           |> AuthToolkit.change_user_registration(user_data)
           |> Ecto.Changeset.apply_action(:validate),
         {:ok, user, confirmation_code} <-
           AuthToolkit.register_user(user_data, socket.assigns.remote_address) do
      {:ok, _} = EmailBackend.get().send_account_confirmation(user, confirmation_code.code)

      {
        :noreply,
        assign(socket,
          trigger_submit: true,
          form: to_form(AuthToolkit.change_user_registration(%User{}, user_data))
        )
      }
    else
      {:error, :rate_limit} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Sorry, we are too busy at the moment. Please try again in a few minutes."
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
