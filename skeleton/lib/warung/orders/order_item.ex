defmodule Warung.Orders.OrderItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Warung.Catalog.Product
  alias Warung.Orders.Order

  schema "order_items" do
    field :quantity, :integer
    field :unit_price, :decimal

    belongs_to :order, Order
    belongs_to :product, Product

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:quantity, :unit_price, :order_id, :product_id])
    |> validate_required([:quantity, :unit_price, :product_id])
    |> validate_number(:quantity, greater_than: 0)
  end
end
