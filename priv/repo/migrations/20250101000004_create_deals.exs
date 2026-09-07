defmodule Alur.Repo.Migrations.CreateDeals do
  @moduledoc """
  Creates the deals table: an opportunity owned by an account, anchored to one
  of that account's contacts, sitting on one of the fixed pipeline columns.
  """
  use Ecto.Migration

  def change do
    create table(:deals, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :pipeline_column_id,
          references(:pipeline_columns, type: :binary_id, on_delete: :restrict),
          null: false

      add :title, :string, null: false
      add :amount, :integer, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:deals, [:account_id])
    create index(:deals, [:contact_id])
    create index(:deals, [:pipeline_column_id])
  end
end
