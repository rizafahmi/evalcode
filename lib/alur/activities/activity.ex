defmodule Alur.Activities.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "activities" do
    field :description, :string
    field :action_type, :string, default: "note"
    field :metadata, :map, default: %{}

    belongs_to :user, Alur.Accounts.User
    belongs_to :deal, Alur.Deals.Deal

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating an activity.
  Activities are append-only; update/delete are disallowed.
  """
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:description, :action_type, :metadata, :deal_id, :user_id])
    |> validate_required([:description, :deal_id, :user_id])
    |> validate_length(:description, min: 1, max: 5000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:deal_id)
  end
end
