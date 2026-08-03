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
    raw_items = Map.get(attrs, :items, [])

    with {:ok, priced} <- price_items(raw_items) do
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
        {:ok, %{order: order, items: inserted}} -> {:ok, %{order | items: inserted}}
        {:error, _step, changeset, _changes} -> {:error, changeset}
      end
    end
  end

  defp price_items([]), do: {:error, :no_items}

  defp price_items(items) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      with {:ok, quantity} <- validate_quantity(Map.get(item, :quantity, 1)),
           %Product{} = product <- Repo.get(Product, Map.get(item, :product_id)) do
        priced = %{product_id: product.id, quantity: quantity, unit_price: product.price}
        {:cont, {:ok, [priced | acc]}}
      else
        nil -> {:halt, {:error, :product_not_found}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp validate_quantity(quantity) when is_integer(quantity) and quantity > 0,
    do: {:ok, quantity}

  defp validate_quantity(_quantity), do: {:error, :invalid_quantity}

  defp line_total(%{unit_price: price, quantity: quantity}) do
    Decimal.mult(price, Decimal.new(quantity))
  end
end
