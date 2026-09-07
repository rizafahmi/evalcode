defmodule Alur.Repo.Migrations.CreatePipelineColumns do
  @moduledoc """
  Creates the fixed pipeline columns and seeds the starting set (Lead, Meeting,
  Proposal, Won, Lost) that v1 always ships with. Columns are reference data:
  v1 never lets users add, rename, reorder, or delete them.
  """
  use Ecto.Migration

  defmodule SeedPipelineColumn do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "pipeline_columns" do
      field(:name, :string)
      field(:order, :integer)
      field(:inserted_at, :utc_datetime)
      field(:updated_at, :utc_datetime)
    end
  end

  @columns [
    {"Lead", 1},
    {"Meeting", 2},
    {"Proposal", 3},
    {"Won", 4},
    {"Lost", 5}
  ]

  def up do
    create table(:pipeline_columns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :order, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pipeline_columns, [:name])
    create unique_index(:pipeline_columns, [:order])

    flush()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(@columns, fn {name, order} ->
        %{
          id: Ecto.UUID.generate(),
          name: name,
          order: order,
          inserted_at: now,
          updated_at: now
        }
      end)

    repo().insert_all(SeedPipelineColumn, rows)
  end

  def down do
    drop table(:pipeline_columns)
  end
end
