defmodule Warung.Orders do
  @moduledoc """
  Placing and listing customer orders.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Warung.Catalog.Product
  alias Warung.Orders.Order
  alias Warung.Orders.OrderItem
  alias Warung.Repo

  def list_orders do
    Repo.all(from o in Order, order_by: [desc: o.inserted_at, desc: o.id], preload: [:items])
  end

  def create_order(attrs) do
    items = Map.get(attrs, :items, [])

    with {:ok, priced} <- price_items(items) do
      total = Enum.reduce(priced, Decimal.new(0), &Decimal.add(line_total(&1), &2))

      Multi.new()
      |> Multi.insert(
        :order,
        Order.changeset(%Order{}, %{
          customer_email: Map.get(attrs, :customer_email),
          total: total
        })
      )
      |> Multi.run(:items, fn repo, %{order: order} ->
        inserted =
          Enum.map(priced, fn item ->
            repo.insert!(OrderItem.changeset(%OrderItem{}, Map.put(item, :order_id, order.id)))
          end)

        {:ok, inserted}
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{order: order, items: items}} -> {:ok, %{order | items: items}}
        {:error, _step, changeset, _changes} -> {:error, changeset}
      end
    end
  end

  defp price_items([]), do: {:error, :no_items}

  defp price_items(items) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
      case Repo.get(Product, Map.get(item, :product_id)) do
        nil ->
          {:halt, {:error, :product_not_found}}

        product ->
          {:cont,
           {:ok,
            acc ++
              [
                %{
                  product_id: product.id,
                  quantity: Map.get(item, :quantity, 1),
                  unit_price: product.price
                }
              ]}}
      end
    end)
  end

  defp line_total(%{unit_price: price, quantity: quantity}) do
    Decimal.mult(price, Decimal.new(quantity))
  end
end
