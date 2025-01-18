defmodule AuthToolkit.Emails.CodeComponent do
  @moduledoc false
  use MjmlEEx.Component, mode: :runtime

  @impl true
  def render(assigns) do
    """
    <mj-section background-color="#F5F6FF" padding="10px" border-radius="8px">
      <mj-column>
        <mj-text
          font-size="32px"
          font-weight="bold"
          align="center"
          color="#4A54F1"
          >#{assigns[:code]}</mj-text
        >
      </mj-column>
    </mj-section>
    """
  end
end
