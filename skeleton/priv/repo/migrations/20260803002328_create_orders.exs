defmodule Warung.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add :customer_email, :string, null: false
      add :total, :decimal, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:order_items) do
      add :quantity, :integer, null: false
      add :unit_price, :decimal, null: false
      add :order_id, references(:orders, on_delete: :delete_all), null: false
      add :product_id, references(:products, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:order_items, [:order_id])
    create index(:order_items, [:product_id])
  end
end
