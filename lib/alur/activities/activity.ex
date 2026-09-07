defmodule Alur.Activities.Activity do
  @moduledoc """
  One immutable line in a deal's activity log: a short description of what
  happened (created, moved, a follow-up event, or a manual note) stamped with
  the moment it was written.

  Lines are written once and never edited or deleted through the app — the
  `when` of a line is its `inserted_at`, and nothing in this schema exposes
  update or delete behaviour.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Alur.Deals.Deal

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @max_description_length 500

  schema "activities" do
    field :description, :string

    belongs_to :deal, Deal

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  A changeset for a new log line.

  Only `description` is cast — the owning `deal_id` is stamped by the
  Activities context and can never be changed through a form.
  """
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:description])
    |> validate_required([:description, :deal_id])
    |> validate_length(:description,
      max: @max_description_length,
      message: "should be at most #{@max_description_length} character(s)"
    )
  end
end
