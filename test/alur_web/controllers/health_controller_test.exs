defmodule AlurWeb.HealthControllerTest do
  use AlurWeb.ConnCase

  describe "GET /api/health" do
    test "returns 200 with status ok unauthenticated", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      assert json_response(conn, 200) == %{"status" => "ok"}
    end
  end
end
