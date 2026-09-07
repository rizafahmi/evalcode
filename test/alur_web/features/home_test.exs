defmodule AlurWeb.HomeTest do
  use AlurWeb.ConnCase, async: true

  test "GET / returns a 200 response", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", text: "Phoenix Framework")
  end
end
