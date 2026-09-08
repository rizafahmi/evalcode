defmodule Alur.Repo.Migrations.CreatePipelineColumnsAndDeals do
  use Ecto.Migration

  def change do
    create table(:pipeline_columns, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :position, :integer, null: false
    end

    create unique_index(:pipeline_columns, [:position])

    create table(:deals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :amount, :integer, null: false
      add :notes, :text
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :contact_id, references(:contacts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :pipeline_column_id, references(:pipeline_columns, type: :string), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:deals, [:user_id])
    create index(:deals, [:contact_id])
    create index(:deals, [:pipeline_column_id])

    flush()

    execute """
    INSERT INTO pipeline_columns (id, name, position) VALUES
      ('lead', 'Lead', 0),
      ('meeting', 'Meeting', 1),
      ('proposal', 'Proposal', 2),
      ('won', 'Won', 3),
      ('lost', 'Lost', 4)
    """
  end
end
