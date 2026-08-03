defmodule Warung.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :sku, :string
    field :name, :string
    field :price, :decimal
    field :stock, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:sku, :name, :price, :stock])
    |> validate_required([:sku, :name, :price])
    |> validate_number(:stock, greater_than_or_equal_to: 0)
    |> unique_constraint(:sku)
  end
end
