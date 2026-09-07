defmodule AlurWeb.AuthFlowTest do
  use AlurWeb.ConnCase, async: false

  @email "budi@example.com"
  @password "super secret 1234"

  defp register(conn) do
    conn
    |> post(~p"/accounts/register", account: %{email: @email, password: @password})
  end

  test "registering signs the account in and lands on the pipeline", %{conn: conn} do
    conn = register(conn)

    assert conn.status == 302
    assert Phoenix.ConnTest.redirected_to(conn) == "/"
    assert get_session(conn, :account_token)
  end

  test "a signed-in account can log out and the log-in page confirms it", %{conn: conn} do
    conn =
      conn
      |> register()
      |> recycle()
      |> delete(~p"/accounts/log-out")

    assert conn.status == 302
    assert Phoenix.ConnTest.redirected_to(conn) == "/accounts/log-in"
    refute get_session(conn, :account_token)

    conn =
      conn
      |> recycle()
      |> get(~p"/accounts/log-in")

    assert html_response(conn, 200) =~ "Logged out successfully."
  end

  test "an invalid log in renders the form again with an error", %{conn: conn} do
    conn =
      conn
      |> register()
      |> recycle()
      |> delete(~p"/accounts/log-out")
      |> recycle()

    conn =
      post(conn, ~p"/accounts/log-in", account: %{email: @email, password: "nope"})

    assert html_response(conn, 200) =~ "Invalid email or password"
  end
end
