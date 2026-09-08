defmodule AlurWeb.Api.HealthControllerTest do
  use AlurWeb.ConnCase

  test "GET /api/health returns an unauthenticated health response", %{conn: conn} do
    conn = get(conn, ~p"/api/health")

    assert response(conn, 200) == ~s({"status":"ok"})
  end
end
