defmodule AuthToolkit.Emails.ResetPasswordTemplate do
  @moduledoc false
  use MjmlEEx,
    mjml_template: "reset_password.mjml",
    layout: AuthToolkit.Emails.Layout
end
