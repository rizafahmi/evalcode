defmodule Alur.Repo.Migrations.CreateActivities do
  @moduledoc """
  Creates the activities table: the immutable, timestamped log lines a deal
  keeps (created, moved, later follow-up events, and manual notes).

  An activity only ever belongs to one deal and is deleted with it, so the
  foreign key cascades and the log can never outlive its deal.
  """
  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :deal_id, references(:deals, type: :binary_id, on_delete: :delete_all), null: false

      add :description, :text, null: false

      # Microsecond timestamps so two lines written in the same second still
      # order deterministically (the deal log is newest-first).
      timestamps(type: :utc_datetime_usec)
    end

    create index(:activities, [:deal_id])
  end
end
