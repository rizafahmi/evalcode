defmodule Alur.Deals.PipelineColumn do
  @moduledoc "A fixed stage in the Alur deal pipeline."

  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}

  schema "pipeline_columns" do
    field :name, :string
    field :position, :integer
  end
end
