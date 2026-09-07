defmodule Alur.Repo.Migrations.CreatePipelineColumnsAndDeals do
  use Ecto.Migration

  def change do
    create table(:pipeline_columns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :order, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pipeline_columns, [:name])
    create unique_index(:pipeline_columns, [:order])

    execute(
      """
      INSERT INTO pipeline_columns (id, name, "order", inserted_at, updated_at)
      VALUES
        ('0191c78a-0001-7000-8000-000000000001', 'Lead', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('0191c78a-0002-7000-8000-000000000002', 'Meeting', 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('0191c78a-0003-7000-8000-000000000003', 'Proposal', 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('0191c78a-0004-7000-8000-000000000004', 'Won', 4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('0191c78a-0005-7000-8000-000000000005', 'Lost', 5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      """,
      """
      DELETE FROM pipeline_columns
      """
    )

    create table(:deals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :pipeline_column_id,
          references(:pipeline_columns, type: :binary_id, on_delete: :restrict),
          null: false

      add :title, :string, null: false
      add :amount, :integer, null: false, default: 0
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:deals, [:user_id])
    create index(:deals, [:contact_id])
    create index(:deals, [:pipeline_column_id])
    create index(:deals, [:user_id, :pipeline_column_id])
  end
end
