defmodule WarungWeb.OrderLiveTest do
  use WarungWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Warung.Catalog
  alias Warung.Orders

  defp product(name, price) do
    {:ok, product} =
      Catalog.create_product(%{
        sku: "SKU-#{System.unique_integer([:positive])}",
        name: name,
        price: Decimal.new(price),
        stock: 100
      })

    product
  end

  test "lists existing orders", %{conn: conn} do
    tea = product("Teh", "12.50")

    {:ok, _} =
      Orders.create_order(%{
        customer_email: "budi@example.com",
        items: [%{product_id: tea.id, quantity: 1}]
      })

    {:ok, view, _html} = live(conn, ~p"/orders")

    assert has_element?(view, "#orders")
    assert render(view) =~ "budi@example.com"
  end

  test "renders on a disconnected mount", %{conn: conn} do
    tea = product("Teh", "12.50")

    {:ok, _} =
      Orders.create_order(%{
        customer_email: "static@example.com",
        items: [%{product_id: tea.id, quantity: 1}]
      })

    conn = get(conn, ~p"/orders")
    assert html_response(conn, 200) =~ "static@example.com"
  end

  test "places an order through the form", %{conn: conn} do
    tea = product("Teh", "12.50")

    {:ok, view, _html} = live(conn, ~p"/orders")

    view
    |> form("#place-order", %{
      "customer_email" => "siti@example.com",
      "product_id" => tea.id,
      "quantity" => "2"
    })
    |> render_submit()

    assert render(view) =~ "siti@example.com"
    assert [order] = Orders.list_orders()
    assert Decimal.equal?(order.total, Decimal.new("25.00"))
  end

  test "shows an error when the form is invalid", %{conn: conn} do
    tea = product("Teh", "12.50")

    {:ok, view, _html} = live(conn, ~p"/orders")

    html =
      view
      |> form("#place-order", %{
        "customer_email" => "",
        "product_id" => tea.id,
        "quantity" => "1"
      })
      |> render_submit()

    assert html =~ "could not be placed"
    assert Orders.list_orders() == []
  end

  test "does not crash on a non-numeric quantity", %{conn: conn} do
    tea = product("Teh", "12.50")

    {:ok, view, _html} = live(conn, ~p"/orders")

    html =
      view
      |> form("#place-order", %{
        "customer_email" => "siti@example.com",
        "product_id" => tea.id,
        "quantity" => "two"
      })
      |> render_submit()

    assert html =~ "could not be placed"
    assert Orders.list_orders() == []
  end

  test "does not crash on an empty quantity", %{conn: conn} do
    tea = product("Teh", "12.50")

    {:ok, view, _html} = live(conn, ~p"/orders")

    html =
      view
      |> form("#place-order", %{
        "customer_email" => "siti@example.com",
        "product_id" => tea.id,
        "quantity" => ""
      })
      |> render_submit()

    assert html =~ "could not be placed"
    assert Orders.list_orders() == []
  end
end
