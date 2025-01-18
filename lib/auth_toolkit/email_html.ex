defmodule AuthToolkit.EmailHTML do
  use AuthToolkitWeb, :html

  embed_templates("email_templates/*")
end
