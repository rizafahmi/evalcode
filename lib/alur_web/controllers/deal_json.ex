defmodule AlurWeb.DealJSON do
  @moduledoc """
  Renders JSON representations for Deal API endpoints.
  """

  @doc """
  Renders a list of deals.
  """
  def index(%{deals: deals}) do
    Enum.map(deals, &data/1)
  end

  @doc """
  Renders a single deal.
  """
  def show(%{deal: deal}) do
    data(deal)
  end

  @doc """
  Transforms a `%Deal{}` struct into a map suitable for JSON serialization.
  """
  def data(deal) do
    %{
      id: deal.id,
      title: deal.title,
      amount: deal.amount,
      notes: deal.notes,
      pipeline_column_id: deal.pipeline_column_id,
      contact_id: deal.contact_id,
      contact:
        if Ecto.assoc_loaded?(deal.contact) and not is_nil(deal.contact) do
          %{
            id: deal.contact.id,
            name: deal.contact.name,
            email: deal.contact.email,
            phone: deal.contact.phone
          }
        else
          nil
        end,
      inserted_at: deal.inserted_at,
      updated_at: deal.updated_at
    }
  end
end
