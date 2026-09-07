defmodule Alur.NextActions.NextAction do
  @moduledoc """
  A follow-up scheduled on a deal: what needs doing, when it is due (a date
  with an optional time), and whether it has been completed.

  Incomplete follow-ups of the account's deals appear on the To-dos page,
  soonest due first; completed ones stay visible on the deal page.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Alur.Deals.Deal

  @max_what_length 200

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "next_actions" do
    field :what, :string
    field :due_date, :date
    field :due_time, :time
    field :done, :boolean, default: false

    belongs_to :deal, Deal

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating a follow-up or completing one.

  Only the follow-up's own fields are cast — the owning `deal_id` is stamped by
  the NextActions context and can never be changed through a form. `what` and
  `due_date` are required; `due_time` is optional; `done` defaults to false and
  is only ever set to true by the context's complete path.
  """
  def changeset(next_action, attrs) do
    next_action
    |> cast(attrs, [:what, :due_date, :due_time, :done])
    |> validate_required([:what, :due_date, :deal_id])
    |> validate_length(:what,
      max: @max_what_length,
      message: "should be at most #{@max_what_length} character(s)"
    )
  end
end
