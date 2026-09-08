defmodule AlurWeb.ShellTest do
  use AlurWeb.ConnCase

  import Alur.AccountsFixtures

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture())}
  end

  test "authenticated users can move between the shell sections", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", text: "Pipeline")
    |> click_link("Contacts")
    |> assert_has("h1", text: "Contacts")
    |> click_link("To-dos")
    |> assert_has("h1", text: "To-dos")
  end
end
