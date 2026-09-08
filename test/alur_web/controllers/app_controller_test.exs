defmodule AlurWeb.AppControllerTest do
  use AlurWeb.ConnCase

  test "GET /app requires authentication", %{conn: conn} do
    conn = get(conn, ~p"/app")

    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "GET /app renders an empty Vue mount node for signed-in users", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    conn = get(conn, ~p"/app")

    assert html_response(conn, 200) =~ ~s(<div id="vue-app"></div>)
  end
end
