defmodule Alur.Deals.Deal do
  @moduledoc "A sales opportunity managed by an Alur account."

  use Ecto.Schema
  import Ecto.Changeset

  alias Alur.Accounts.User
  alias Alur.Contacts.Contact
  alias Alur.Deals.Activity
  alias Alur.Deals.NextAction
  alias Alur.Deals.PipelineColumn

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "deals" do
    field :title, :string
    field :amount, :integer
    field :notes, :string

    belongs_to :user, User
    belongs_to :contact, Contact
    belongs_to :pipeline_column, PipelineColumn, type: :string
    has_many :activities, Activity
    has_many :next_actions, NextAction

    timestamps(type: :utc_datetime)
  end

  @doc "Builds a changeset for deal creation and updates."
  def changeset(deal, attrs) do
    deal
    |> cast(attrs, [:title, :amount, :notes, :contact_id, :pipeline_column_id])
    |> validate_required([:title, :amount, :contact_id, :pipeline_column_id])
    |> validate_length(:title, max: 160)
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> validate_length(:notes, max: 10_000)
  end
end
