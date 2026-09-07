defmodule Alur.DealsFixtures do
  @moduledoc """
  Test helpers for creating deals via the `Alur.Deals` context.
  """

  alias Alur.Accounts.Scope
  alias Alur.ContactsFixtures
  alias Alur.Deals

  def unique_deal_title, do: "Deal #{System.unique_integer([:positive])}"

  def valid_deal_attributes(%Scope{} = scope, attrs \\ %{}) do
    contact_id =
      attrs[:contact_id] ||
        attrs["contact_id"] ||
        ContactsFixtures.contact_fixture(scope).id

    default_column = Deals.default_pipeline_column()

    column_id =
      attrs[:pipeline_column_id] ||
        attrs["pipeline_column_id"] ||
        default_column.id

    Enum.into(attrs, %{
      title: unique_deal_title(),
      amount: 15_000_000,
      notes: "Sample opportunity notes",
      contact_id: contact_id,
      pipeline_column_id: column_id
    })
  end

  def deal_fixture(%Scope{} = scope, attrs \\ %{}) do
    attrs = valid_deal_attributes(scope, attrs)
    {:ok, deal} = Deals.create_deal(scope, attrs)
    deal
  end
end
