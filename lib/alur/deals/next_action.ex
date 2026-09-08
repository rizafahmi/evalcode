defmodule Alur.Deals.NextAction do
  @moduledoc "A scheduled follow-up for a deal."

  use Ecto.Schema
  import Ecto.Changeset

  alias Alur.Accounts.User
  alias Alur.Deals.Deal

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "next_actions" do
    field :description, :string
    field :due, :utc_datetime_usec
    field :done, :boolean, default: false
    field :due_date, :string, virtual: true
    field :due_time, :string, virtual: true

    belongs_to :user, User
    belongs_to :deal, Deal

    timestamps(type: :utc_datetime)
  end

  def changeset(next_action, attrs) do
    next_action
    |> cast(attrs, [:description, :due, :done])
    |> validate_required([:description, :due])
    |> validate_length(:description, max: 10_000)
  end
end
