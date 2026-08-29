defmodule SorakWeb.HomeTest do
  use SorakWeb.ConnCase, async: true

  test "render home page", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", text: "Phoenix Framework")
  end
end
