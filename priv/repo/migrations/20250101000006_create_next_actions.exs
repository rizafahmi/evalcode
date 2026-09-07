defmodule Alur.Repo.Migrations.CreateNextActions do
  @moduledoc """
  Creates the next_actions table: the follow-ups a deal carries.

  A follow-up has a description (`what`), a due date with an optional time, and
  a done flag. It only ever belongs to one deal and is deleted with it, so the
  foreign key cascades and a follow-up can never outlive its deal (or the
  contact that owns the deal).
  """
  use Ecto.Migration

  def change do
    create table(:next_actions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false

      add :what, :text, null: false
      add :due_date, :date, null: false
      add :due_time, :time
      add :done, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:next_actions, [:deal_id])
    create index(:next_actions, [:done, :due_date, :due_time])
  end
end
