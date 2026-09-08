defmodule Alur.Deals.Activity do
  @moduledoc "An immutable event recorded against a deal."

  use Ecto.Schema
  import Ecto.Changeset

  alias Alur.Accounts.User
  alias Alur.Deals.Deal

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "activities" do
    field :description, :string

    belongs_to :user, User
    belongs_to :deal, Deal

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Builds a changeset for an activity entry."
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:description])
    |> validate_required(:description)
    |> validate_length(:description, max: 10_000)
  end
end
