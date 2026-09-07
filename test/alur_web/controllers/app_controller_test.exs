defmodule AlurWeb.AppControllerTest do
  use AlurWeb.ConnCase

  import Alur.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "GET /app" do
    test "redirects unauthenticated user to log in", %{conn: conn} do
      conn = get(conn, ~p"/app")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "renders empty mount node for authenticated user", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/app")

      response = html_response(conn, 200)
      assert response =~ ~s(<div id="app"></div>)
    end
  end
end
