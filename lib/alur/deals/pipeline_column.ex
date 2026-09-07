defmodule Alur.Deals.PipelineColumn do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "pipeline_columns" do
    field :name, :string
    field :order, :integer

    has_many :deals, Alur.Deals.Deal

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for a pipeline column.
  """
  def changeset(column, attrs) do
    column
    |> cast(attrs, [:name, :order])
    |> validate_required([:name, :order])
    |> unique_constraint(:name)
    |> unique_constraint(:order)
  end
end
