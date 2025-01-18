defmodule AuthToolkitWeb.Components do
  @moduledoc false
  use Phoenix.Component

  import Phoenix.HTML, only: [html_escape: 1]

  alias Phoenix.HTML.FormField

  attr(:for, :any, required: true, doc: "the datastructure for the form")
  attr(:as, :any, default: nil, doc: "the server side parameter to collect all input under")
  attr(:class, :string, default: nil)

  attr(:rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target),
    doc: "the arbitrary HTML attributes to apply to the form tag"
  )

  slot(:inner_block, required: true)

  slot(:actions, doc: "the slot for form actions, such as a submit button") do
  end

  slot(:destructive_actions, doc: "the slot for form actions, such as a submit button") do
  end

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} novalidate class={["form-simple", @class]} {@rest}>
      <%= render_slot(@inner_block, f) %>
      <div class="form-actions">
        <div>
          <div :for={action <- @destructive_actions} class="form-action-group">
            <%= render_slot(action, f) %>
          </div>
        </div>
        <div>
          <div :for={action <- @actions} class="form-action-group">
            <%= render_slot(action, f) %>
          </div>
        </div>
      </div>
    </.form>
    """
  end

  attr(:class, :string, default: nil)
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the container")
  slot(:inner_block, required: true)

  def box(assigns) do
    ~H"""
    <div class={["box", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr(:class, :string, default: "")
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the container")
  slot(:inner_block, required: true)

  def group_box(assigns) do
    ~H"""
    <div class={["box-group", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  slot(:inner_block, required: true)

  def form_box(assigns) do
    ~H"""
    <.box class="form-box">
      <div class="form-box-content">
        <%= render_slot(@inner_block) %>
      </div>
    </.box>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `%Phoenix.HTML.Form{}` and field name may be passed to the input
  to build input names and error messages, or all the attributes and
  errors may be passed explicitly.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr(:id, :any, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:value, :any)

  attr(:type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
                   range radio search select tel text textarea time url week
                   timezone radio_group checkbox_group)
  )

  attr(:field, FormField, doc: "a form field struct retrieved from the form, for example: @form[:email]")

  attr(:errors, :list, default: [])
  attr(:checked, :boolean, doc: "the checked flag for checkbox inputs")
  attr(:prompt, :string, default: nil, doc: "the prompt for select inputs")
  attr(:options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2")
  attr(:multiple, :boolean, default: false, doc: "the multiple flag for select inputs")

  attr(:rest, :global, include: ~w(autocomplete cols disabled form list max maxlength min minlength
                    pattern placeholder readonly required rows size step))

  slot(:feedback)
  slot(:inner_block)

  def input(%{field: %FormField{} = field} = assigns) do
    input(prepare_input_assigns(assigns, field))
  end

  def input(%{type: "checkbox", value: value} = assigns) do
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
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "timezone"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} {@rest} phx-hook="TimezoneSelector" id={"timezone-selector-#{@id}"}>
      <.input
        type="text"
        list={"#{@id}-timezones"}
        name={@name}
        id={@id}
        value={@value}
        label={@label}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
      <datalist id={"#{@id}-timezones"}>
        <option :for={timezone <- Tzdata.zone_list()} value={timezone} />
      </datalist>
    </div>
    """
  end

  def input(%{type: "radio_group"} = assigns) do
    ~H"""
    <div class="pb-4 space-y-2">
      <.radio_button
        :for={{value, label} <- @options}
        value={value}
        name={@name}
        checked={html_escape(value) == html_escape(@value)}
      >
        <%= label %>
      </.radio_button>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "checkbox_group"} = assigns) do
    assigns = Map.update!(assigns, :value, fn v -> Enum.map(v, &to_string/1) end)

    ~H"""
    <div class="flex justify-between">
      <.large_checkbox
        :for={{value, label} <- @options}
        id={"large-checkbox-#{value}"}
        name={"#{@name}[]"}
        value={value}
        checked={to_string(value) in @value}
        {@rest}
      >
        <%= label %>
      </.large_checkbox>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class="select-input"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={@label != []} for={@id} class="input-label"><%= @label %></.label>
      <.error :for={msg <- @errors}><%= msg %></.error>
      <div class="input-container">
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class="text-input"
          {@rest}
        />
        <%= render_slot(@feedback) %>
      </div>

      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  def prepare_input_assigns(assigns, field) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
  end

  @doc """
  Renders a label.
  """
  attr(:for, :string, default: nil)
  attr(:class, :string, default: "")
  slot(:inner_block, required: true)

  def label(assigns) do
    ~H"""
    <label for={@for} class={["label", @class]}>
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot(:inner_block, required: true)

  def error(assigns) do
    ~H"""
    <p class="error-message">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  slot(:inner_block)

  def screen_header(assigns) do
    ~H"""
    <h1 class="screen-header">
      <%= render_slot(@inner_block) %>
    </h1>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr(:class, :string, default: nil)

  slot(:inner_block, required: true)
  slot(:subtitle)
  slot(:actions)

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "header-with-actions", @class]}>
      <div>
        <h2 class="header-title">
          <%= render_slot(@inner_block) %>
        </h2>
        <p :if={@subtitle != []} class="header-subtitle">
          <%= render_slot(@subtitle) %>
        </p>
      </div>
      <div class="header-actions"><%= render_slot(@actions) %></div>
    </header>
    """
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(AuthToolkitWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(AuthToolkitWeb.Gettext, "errors", msg, opts)
    end
  end

  attr(:type, :string, default: "submit")
  attr(:rest, :global, include: ~w(disabled form name value))
  slot(:inner_block, required: true)

  def submit_button(assigns) do
    ~H"""
    <.primary_button {@rest}>
      <%= render_slot(@inner_block) %>
    </.primary_button>
    """
  end

  attr(:type, :string, default: "submit")
  attr(:class, :string, default: "")
  attr(:rest, :global, include: ~w(disabled form name value))
  slot(:inner_block, required: true)

  def primary_button(assigns) do
    ~H"""
    <button type={@type} class={["button-primary", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr(:type, :string, default: "submit")
  attr(:class, :string, default: "")
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def destructive_button(assigns) do
    ~H"""
    <button type={@type} class={["button-destructive", @class]} data-confirm="Are you sure?" {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr(:class, :string, default: nil)
  attr(:rest, :global, include: ~w(navigate href))
  slot(:inner_block, required: true)

  def primary_link(assigns) do
    ~H"""
    <.link
      class={[
        "primary-link",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  def divider(assigns) do
    ~H"""
    <hr class="content-divider" />
    """
  end

  attr(:class, :string, default: nil)
  attr(:method, :any, default: nil)
  attr(:rest, :global, include: ~w(navigate href))
  slot(:inner_block, required: true)

  def inline_link(assigns) do
    ~H"""
    <.link
      class={[
        "inline-link",
        @class
      ]}
      method={@method}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  def check_mark(assigns) do
    ~H"""
    <svg
      class="check-mark-icon"
      fill="currentcolor"
      viewbox="0 0 20 20"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        fill-rule="evenodd"
        d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
        clip-rule="evenodd"
      >
      </path>
    </svg>
    """
  end

  slot(:inner_block, required: true)

  def check_item(assigns) do
    ~H"""
    <li class="check-list-item">
      <.check_mark />
      <span class="check-list-text"><%= render_slot(@inner_block) %></span>
    </li>
    """
  end

  slot(:inner_block)

  def inline_contact_link(assigns) do
    ~H"""
    <.inline_link href="mailto:info@beepr.app">
      <%= render_slot(@inner_block) %>
    </.inline_link>
    """
  end

  def create_button(assigns) do
    ~H"""
    <.primary_button phx-disable-with="Creating...">Create</.primary_button>
    """
  end

  def save_button(assigns) do
    ~H"""
    <.primary_button phx-disable-with="Saving...">Save</.primary_button>
    """
  end

  attr(:rest, :global)

  def delete_button(assigns) do
    ~H"""
    <.destructive_button class="delete" {@rest}>Delete</.destructive_button>
    """
  end

  attr(:name, :string, required: true)
  attr(:value, :string, required: true)
  attr(:checked, :boolean, default: false)
  slot(:inner_block, required: true)

  def radio_button(assigns) do
    ~H"""
    <label class="radio-label">
      <input
        type="radio"
        name={@name}
        value={@value}
        checked={@checked}
        class="radio-input"
      /> <%= render_slot(@inner_block) %>
    </label>
    """
  end

  attr(:id, :string, required: true)
  attr(:name, :any)
  attr(:value, :any)
  attr(:checked, :boolean, default: false)
  attr(:class, :string, default: "")
  slot(:inner_block, required: true)

  def large_checkbox(assigns) do
    ~H"""
    <div class="large-checkbox-container">
      <input
        type="checkbox"
        class="large-checkbox-input"
        id={@id}
        checked={@checked}
        name={@name}
        value={@value}
      />
      <label
        class={[
          "large-checkbox-label",
          @class
        ]}
        for={@id}
      >
        <%= render_slot(@inner_block) %>
      </label>
    </div>
    """
  end

  attr(:cols, :integer, default: 12)
  attr(:class, :string, default: "")
  slot(:inner_block)

  def grid(assigns) do
    # Manual lookup so that Tailwind picks up the classes
    grid_cols_class =
      case assigns.cols do
        12 ->
          "lg:grid-cols-12"

        10 ->
          "lg:grid-cols-10"
          # 8 -> "lg:grid-cols-8"
          # 6 -> "lg:grid-cols-6"
          # 4 -> "lg:grid-cols-4"
          # 2 -> "lg:grid-cols-2"
      end

    assigns = Map.put(assigns, :grid_cols_class, grid_cols_class)

    ~H"""
    <div class={["lg:grid lg:gap-8", @grid_cols_class, @class]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr(:span, :integer, default: 12)
  attr(:class, :string, default: "")
  slot(:inner_block)

  def grid_col(assigns) do
    # Manual lookup so that Tailwind picks up the classes
    col_span_class =
      case assigns.span do
        # 12 -> "col-span-12"
        10 -> "col-span-10"
        8 -> "col-span-8"
        6 -> "col-span-6"
        # 5 -> "col-span-5"
        4 -> "col-span-4"
        # 2 -> "col-span-2"
        1 -> "col-span-1"
      end

    assigns = Map.put(assigns, :col_span_class, col_span_class)

    ~H"""
    <div class={[@col_span_class, @class]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  slot(:inner_block)

  def top_level_screen(assigns) do
    ~H"""
    <.grid cols={12} class="mx-8 my-8 sm:my-6 lg:mx-0 lg:my-12">
      <.grid_col span={1} class="hidden lg:block" />
      <.grid_col span={10}>
        <%= render_slot(@inner_block) %>
      </.grid_col>
      <.grid_col span={1} class="hidden lg:block" />
    </.grid>
    """
  end

  slot(:inner_block, required: true)

  def h2(assigns) do
    ~H"""
    <h2 class="heading-2">
      <%= render_slot(@inner_block) %>
    </h2>
    """
  end

  attr(:class, :string, default: "")
  slot(:inner_block, required: true)

  def p(assigns) do
    ~H"""
    <p class={["paragraph", @class]}>
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  attr(:class, :string, default: "")
  slot(:inner_block, required: true)

  def page_header(assigns) do
    ~H"""
    <h1 class={["page-header", @class]}>
      <%= render_slot(@inner_block) %>
    </h1>
    """
  end

  def help(assigns) do
    ~H"""
    <section class="help-section">
      <div class="help-content">
        <.h2>
          We're here to help.
        </.h2>
        <.p>
          Always humans, never bots. For pre-sales questions, existing
          customers who need a hand, or other inquiries,
          <.inline_contact_link>contact us</.inline_contact_link>
          and we'll get back to you.
        </.p>
      </div>
      <div class="help-grid"></div>
    </section>
    """
  end

  slot(:inner_block, required: true)
  slot(:subtitle)

  def section_header(assigns) do
    ~H"""
    <div class="section-header">
      <h1 class="section-title">
        <%= render_slot(@inner_block) %>
      </h1>
      <.p :if={@subtitle != []}>
        <%= render_slot(@subtitle) %>
      </.p>
    </div>
    """
  end

  attr(:icon_name, :string, default: nil)
  attr(:class, :string, default: "")
  attr(:navigate, :string, required: true)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def nav_button(assigns) do
    ~H"""
    <.link class={["nav-button", @class]} navigate={@navigate} {@rest}>
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  attr(:class, :string, default: "")
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def regular_button(assigns) do
    ~H"""
    <button class={["regular-button", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr(:id, :string, required: true)
  attr(:close_event, :string, default: "close-modal")
  attr(:size, :atom, default: :medium, values: ~w(small medium)a)
  slot(:inner_block, required: true)

  def modal_dialog(assigns) do
    ~H"""
    <div id={@id} phx-hook="ModalDialog" data-close-event={@close_event}>
      <div class="modal-wrapper" role="dialog" aria-modal="true">
        <div class="modal-backdrop"></div>
      </div>

      <div class={[
        "modal-container",
        if(@size == :small, do: "modal-small", else: "modal-medium")
      ]}>
        <div class="modal-header">
          <div class="modal-close">
            <button type="button" phx-click={@close_event} class="close-button">
              <span class="sr-only">Close</span>
              <svg
                class="close-icon"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>
        <div class="modal-body">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end
end
