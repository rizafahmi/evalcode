defmodule Warung.OrdersTest do
  use Warung.DataCase, async: true

  alias Warung.Catalog
  alias Warung.Orders
  alias Warung.Orders.Order

  defp product(attrs) do
    {:ok, product} =
      Catalog.create_product(
        Enum.into(attrs, %{sku: "SKU-#{System.unique_integer([:positive])}", stock: 100})
      )

    product
  end

  describe "create_order/1" do
    test "creates an order and computes the total from unit prices" do
      tea = product(%{name: "Teh", price: Decimal.new("12.50")})
      kopi = product(%{name: "Kopi", price: Decimal.new("3.25")})

      assert {:ok, %Order{} = order} =
               Orders.create_order(%{
                 customer_email: "budi@example.com",
                 items: [
                   %{product_id: tea.id, quantity: 2},
                   %{product_id: kopi.id, quantity: 4}
                 ]
               })

      assert order.customer_email == "budi@example.com"
      assert Decimal.equal?(order.total, Decimal.new("38.00"))
      assert length(order.items) == 2
    end

    test "snapshots the unit price at time of order" do
      tea = product(%{name: "Teh", price: Decimal.new("12.50")})

      {:ok, order} =
        Orders.create_order(%{
          customer_email: "a@example.com",
          items: [%{product_id: tea.id, quantity: 1}]
        })

      [item] = order.items
      assert Decimal.equal?(item.unit_price, Decimal.new("12.50"))
    end

    test "rejects an order with no items" do
      assert {:error, :no_items} =
               Orders.create_order(%{customer_email: "a@example.com", items: []})
    end

    test "rejects an order with a missing email" do
      tea = product(%{name: "Teh", price: Decimal.new("1.00")})

      assert {:error, changeset} =
               Orders.create_order(%{
                 customer_email: nil,
                 items: [%{product_id: tea.id, quantity: 1}]
               })

      assert %{customer_email: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects an unknown product" do
      assert {:error, :product_not_found} =
               Orders.create_order(%{
                 customer_email: "a@example.com",
                 items: [%{product_id: -1, quantity: 1}]
               })
    end

    test "rejects a non-positive quantity" do
      tea = product(%{name: "Teh", price: Decimal.new("1.00")})

      assert {:error, :invalid_quantity} =
               Orders.create_order(%{
                 customer_email: "a@example.com",
                 items: [%{product_id: tea.id, quantity: 0}]
               })
    end

    test "rejects a quantity that is not an integer" do
      tea = product(%{name: "Teh", price: Decimal.new("1.00")})

      assert {:error, :invalid_quantity} =
               Orders.create_order(%{
                 customer_email: "a@example.com",
                 items: [%{product_id: tea.id, quantity: "two"}]
               })
    end
  end

  describe "list_orders/0" do
    test "returns orders newest first with items preloaded" do
      tea = product(%{name: "Teh", price: Decimal.new("1.00")})
      attrs = %{items: [%{product_id: tea.id, quantity: 1}]}

      {:ok, first} = Orders.create_order(Map.put(attrs, :customer_email, "first@example.com"))
      {:ok, second} = Orders.create_order(Map.put(attrs, :customer_email, "second@example.com"))

      assert [a, b] = Orders.list_orders()
      assert a.id == second.id
      assert b.id == first.id
      assert [%Warung.Orders.OrderItem{}] = a.items
    end
  end
end
