defmodule Alur.Deals.Deal do
  @moduledoc """
  An opportunity the signed-in account is working, with a value in Indonesian
  Rupiah, anchored to one of the account's contacts and sitting on one of the
  fixed pipeline columns.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Alur.Accounts.Account
  alias Alur.Contacts.Contact
  alias Alur.Deals.PipelineColumn

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "deals" do
    field :title, :string
    field :amount, :integer
    field :notes, :string

    belongs_to :account, Account
    belongs_to :contact, Contact
    belongs_to :pipeline_column, PipelineColumn

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating or updating a deal.

  Only the deal's own fields are cast — the owning `account_id` and the
  anchoring `contact_id` are set by the Deals context and can never be changed
  through a form. `pipeline_column_id` is a normal selectable field so the
  column can be picked (and later changed) on the deal page.
  """
  def changeset(deal, attrs) do
    deal
    |> cast(attrs, [:title, :amount, :notes, :pipeline_column_id])
    |> validate_required([:title, :amount, :contact_id, :pipeline_column_id])
    |> validate_length(:title,
      max: 200,
      message: "should be at most 200 character(s)"
    )
    |> validate_number(:amount,
      greater_than_or_equal_to: 0,
      message: "must be 0 or a positive whole number of rupiah"
    )
  end
end
