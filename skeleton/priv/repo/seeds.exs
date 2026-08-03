# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# `mix ecto.setup` runs it too, which is how a fresh workspace gets its
# products.
#
# Products matter for more than realism: `/orders` renders a product
# `<select>`, and with no products it has no options. A form submitted from an
# empty select carries no `product_id`, so the page answers "That order could
# not be placed." — the dashboard cannot be exercised by hand at all until
# someone works out that a Product has to exist first.
#
# Idempotent on purpose: `mix ecto.reset` runs `ecto.setup` again, and a bare
# `insert!` would raise on the unique `sku` constraint the second time.

alias Warung.Catalog
alias Warung.Catalog.Product
alias Warung.Repo

products = [
  %{sku: "TEH-001", name: "Teh Manis", price: Decimal.new("12.50"), stock: 100},
  %{sku: "KOP-001", name: "Kopi Tubruk", price: Decimal.new("18.00"), stock: 60},
  %{sku: "NAS-001", name: "Nasi Goreng", price: Decimal.new("35.00"), stock: 25}
]

for attrs <- products do
  case Repo.get_by(Product, sku: attrs.sku) do
    nil -> {:ok, _product} = Catalog.create_product(attrs)
    %Product{} -> :ok
  end
end
