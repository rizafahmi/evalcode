defmodule Alur.Repo.Migrations.CreateActivities do
  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :description, :text, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime_usec)
    end

    create index(:activities, [:user_id])
    create index(:activities, [:deal_id, :inserted_at])
  end
end
