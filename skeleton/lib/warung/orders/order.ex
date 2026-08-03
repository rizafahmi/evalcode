defmodule Warung.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  alias Warung.Orders.OrderItem

  schema "orders" do
    field :customer_email, :string
    field :total, :decimal

    has_many :items, OrderItem

    timestamps(type: :utc_datetime)
  end

  def changeset(order, attrs) do
    order
    |> cast(attrs, [:customer_email, :total])
    |> validate_required([:customer_email, :total])
    |> validate_format(:customer_email, ~r/@/, message: "must be an email address")
  end
end
