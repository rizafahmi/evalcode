# Namespaced under `Holdout` on purpose — see `NOTES.md`. A model-authored
# test with the obvious name for the module it just changed used to collide
# with the held-out module when `grade` copied it in, failing the whole
# compile. The module name and the filename both carry the prefix so neither
# can clash.
#
# `async: false` because SQLite locks the whole database file; async writers
# flake roughly one run in thirty.
defmodule WarungWeb.Holdout.OrderLiveRealtimeTest do
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

  defp place(product, email) do
    {:ok, order} =
      Orders.create_order(%{
        customer_email: email,
        items: [%{product_id: product.id, quantity: 1}]
      })

    order
  end

  test "an order placed in one session appears in another", %{conn: conn} do
    tea = product("Teh", "12.50")

    {:ok, watcher, _html} = live(conn, ~p"/orders")
    {:ok, placer, _html} = live(build_conn(), ~p"/orders")

    placer
    |> form("#place-order", %{
      "customer_email" => "live@example.com",
      "product_id" => tea.id,
      "quantity" => "1"
    })
    |> render_submit()

    assert render(watcher) =~ "live@example.com"
  end

  @tag :discriminator
  test "an order created outside any LiveView still appears", %{conn: conn} do
    tea = product("Teh", "12.50")

    {:ok, watcher, _html} = live(conn, ~p"/orders")

    place(tea, "backend@example.com")

    assert render(watcher) =~ "backend@example.com"
  end

  @tag :discriminator
  test "a new order appears first in the list", %{conn: conn} do
    tea = product("Teh", "12.50")
    place(tea, "older@example.com")

    {:ok, watcher, _html} = live(conn, ~p"/orders")
    place(tea, "newer@example.com")

    html = render(watcher)
    assert html =~ "newer@example.com"
    assert html =~ "older@example.com"

    # Ordering is asserted on where the two emails land in the rendered
    # string, not on a row id. The previous version scanned for
    # `id="orders-\d+"`, but that prefix comes from the stream name, which
    # `task.md` only hints at — a model that renamed the stream got a
    # MatchError and scored `no` for correct work.
    {newer_at, _} = :binary.match(html, "newer@example.com")
    {older_at, _} = :binary.match(html, "older@example.com")

    assert newer_at < older_at
  end

  test "two orders in sequence both appear", %{conn: conn} do
    tea = product("Teh", "12.50")

    {:ok, watcher, _html} = live(conn, ~p"/orders")

    place(tea, "one@example.com")
    place(tea, "two@example.com")

    html = render(watcher)
    assert html =~ "one@example.com"
    assert html =~ "two@example.com"
  end

  test "a disconnected mount still renders existing orders", %{conn: conn} do
    tea = product("Teh", "12.50")
    place(tea, "static@example.com")

    conn = get(conn, ~p"/orders")
    assert html_response(conn, 200) =~ "static@example.com"
  end
end
