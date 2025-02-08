defmodule AuthToolkitWeb.UserConfirmationLiveTest do
  use AuthToolkitWeb.ConnCase

  import Mox
  import Phoenix.LiveViewTest

  @moduletag :live_view
  @error_message "Activation code is invalid or has expired."

  setup :verify_on_exit!
  setup :register_and_log_in_user

  describe "Confirm user" do
    test "confirms the user when a valid code is provided", %{conn: conn, user: user} do
      {:ok, confirmation_code} = AuthToolkit.create_confirmation_code(user)

      {:ok, view, _} = live(conn, "/auth/confirm")

      assert {:error, {:redirect, %{to: "/confirmed"}}} =
               render_hook(view, "check_code", %{"code" => confirmation_code.code})
    end

    test "shows an error when an invalid code is provided", %{conn: conn, user: user} do
      {:ok, _confirmation_code} = AuthToolkit.create_confirmation_code(user)

      {:ok, view, _} = live(conn, "/auth/confirm")

      assert render_hook(view, "check_code", %{"code" => "AAAAAA"}) =~ @error_message
    end

    test "does not show error for partial codes", %{conn: conn, user: user} do
      {:ok, _confirmation_code} = AuthToolkit.create_confirmation_code(user)

      {:ok, view, _} = live(conn, "/auth/confirm")

      refute render_hook(view, "check_code", %{"code" => "A"}) =~ @error_message
    end

    test "sends a new confirmation code on resend_code event", %{conn: conn} do
      {:ok, view, _} = live(conn, "/auth/confirm")

      expect(EmailBackendMock, :send_confirmation_code, fn user, code ->
        :ok
      end)

      assert view |> element("a", "resend code") |> render_click() =~
               "A new code has been sent"
    end
  end
end
