defmodule AlurWeb.Features.ApiAndVueScaffoldTest do
  use AlurWeb.ConnCase

  import Alur.AccountsFixtures

  test "GET /api/health returns 200 with status ok unauthenticated", %{conn: conn} do
    conn = get(conn, ~p"/api/health")
    assert json_response(conn, 200) == %{"status" => "ok"}
  end

  test "unauthenticated user visiting /app is redirected to login", %{conn: conn} do
    conn
    |> visit("/app")
    |> assert_path(~p"/users/log-in")
    |> assert_has("[role=alert]", text: "You must log in to access this page.")
  end

  test "authenticated user visiting /app sees the app layout with empty mount node", %{
    conn: conn
  } do
    user = user_fixture()

    session =
      conn
      |> log_in_user(user)
      |> visit("/app")

    session
    |> assert_path("/app")
    |> assert_has("#app")
    |> assert_has("header")
    |> assert_has("a", text: "Alur")
    |> assert_has("a", text: "Log out")
    |> refute_has("nav a", text: "App")
  end

  test "serves the built Vue bundle at /assets/js/vue.js", %{conn: conn} do
    conn = get(conn, "/assets/js/vue.js")
    assert response(conn, 200) =~ "AlurVue"
  end
end
