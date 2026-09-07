defmodule AlurWeb.AppControllerTest do
  use AlurWeb.ConnCase, async: false

  @email "vue@example.com"
  @password "super secret 1234"

  defp register(conn) do
    conn
    |> post(~p"/accounts/register", account: %{email: @email, password: @password})
  end

  test "GET /app redirects a logged-out visitor to the log-in page", %{conn: conn} do
    conn = get(conn, ~p"/app")

    assert conn.status == 302
    assert redirected_to(conn) == "/accounts/log-in"
  end

  test "GET /app renders the controller page with the Vue mount node and entry script",
       %{conn: conn} do
    conn =
      conn
      |> register()
      |> recycle()
      |> get(~p"/app")

    response = html_response(conn, 200)

    # Controller HTML page (not a LiveView): server-side only the empty mount
    # node plus the Vite-built entry script that makes Vue boot.
    assert response =~ ~s(id="app")
    assert response =~ ~s(src="/assets/vue/app.js")
    assert response =~ "Deal board"
    assert response =~ "Log out"
  end
end
