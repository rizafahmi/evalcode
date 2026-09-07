defmodule Alur.Repo.Migrations.CreateNextActions do
  use Ecto.Migration

  def change do
    create table(:next_actions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false
      add :what, :string, null: false
      add :due_date, :date, null: false
      add :due_time, :time
      add :due_at, :utc_datetime, null: false
      add :done, :boolean, default: false, null: false
      add :completed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:next_actions, [:user_id])
    create index(:next_actions, [:deal_id])
    create index(:next_actions, [:user_id, :done, :due_at])
    create index(:next_actions, [:deal_id, :done])
  end
end
