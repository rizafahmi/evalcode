defmodule Alur.Repo.Migrations.CreateNextActions do
  use Ecto.Migration

  def change do
    create table(:next_actions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :description, :text, null: false
      add :due, :utc_datetime_usec, null: false
      add :done, :boolean, null: false, default: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:next_actions, [:user_id, :done, :due])
    create index(:next_actions, [:deal_id, :due])
  end
end
