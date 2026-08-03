defmodule Warung.Catalog do
  @moduledoc """
  Products available for sale.
  """

  import Ecto.Query, warn: false

  alias Warung.Repo
  alias Warung.Catalog.Product

  def list_products do
    Repo.all(from p in Product, order_by: [asc: p.name])
  end

  def get_product!(id), do: Repo.get!(Product, id)

  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end
end
