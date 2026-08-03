defmodule Warung.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :sku, :string, null: false
      add :name, :string, null: false
      add :price, :decimal, null: false
      add :stock, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:products, [:sku])
  end
end
