defmodule AlurWeb.HealthControllerTest do
  use AlurWeb.ConnCase, async: false

  test "GET /api/health is unauthenticated and returns exactly ok", %{conn: conn} do
    conn = get(conn, ~p"/api/health")

    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
