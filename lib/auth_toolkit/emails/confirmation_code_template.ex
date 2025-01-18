defmodule AuthToolkit.Emails.ConfirmationCodeTemplate do
  @moduledoc false
  use MjmlEEx,
    mjml_template: "confirmation_code.mjml",
    layout: AuthToolkit.Emails.Layout
end
