defmodule AuthToolkit.Emails.AccountConfirmationTemplate do
  @moduledoc false
  use MjmlEEx,
    mjml_template: "account_confirmation.mjml",
    layout: AuthToolkit.Emails.Layout
end
