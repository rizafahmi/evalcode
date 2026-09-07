defmodule Alur.Deals.PipelineColumn do
  @moduledoc """
  A column on the pipeline board (Lead, Meeting, Proposal, Won, Lost).

  Columns are reference data seeded once at migration time; v1 never lets a
  user add, rename, reorder, or delete them.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pipeline_columns" do
    field :name, :string
    field :order, :integer

    timestamps(type: :utc_datetime)
  end
end
