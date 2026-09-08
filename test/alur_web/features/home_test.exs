defmodule AlurWeb.HomeTest do
  use AlurWeb.ConnCase

  import Alur.AccountsFixtures

  test "GET / returns a 200 response", %{conn: conn} do
    conn
    |> log_in_user(user_fixture())
    |> visit("/")
    |> assert_has("h1", text: "Pipeline")
    |> assert_has("nav", text: "Contacts")
  end
end
