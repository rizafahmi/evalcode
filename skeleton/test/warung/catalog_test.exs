defmodule Warung.CatalogTest do
  # async: false — SQLite locks the whole database for writes, so concurrent
  # writers intermittently raise (Exqlite.Error) Database busy. Measured at
  # roughly 1 run in 30. A benchmark cannot afford a test suite that fails
  # for reasons unrelated to the work being scored.
  use Warung.DataCase, async: false

  alias Warung.Catalog
  alias Warung.Catalog.Product

  describe "create_product/1" do
    test "creates a product with valid attributes" do
      assert {:ok, %Product{} = product} =
               Catalog.create_product(%{
                 sku: "TEA-01",
                 name: "Teh Botol",
                 price: Decimal.new("12.50"),
                 stock: 10
               })

      assert product.sku == "TEA-01"
      assert Decimal.equal?(product.price, Decimal.new("12.50"))
    end

    test "rejects a product without a sku" do
      assert {:error, changeset} =
               Catalog.create_product(%{name: "No SKU", price: Decimal.new("1")})

      assert %{sku: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a duplicate sku" do
      attrs = %{sku: "DUP-01", name: "First", price: Decimal.new("1.00")}
      assert {:ok, _} = Catalog.create_product(attrs)
      assert {:error, changeset} = Catalog.create_product(%{attrs | name: "Second"})
      assert %{sku: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "list_products/0" do
    test "returns products ordered by name" do
      {:ok, _} = Catalog.create_product(%{sku: "B", name: "Beta", price: Decimal.new("2.00")})
      {:ok, _} = Catalog.create_product(%{sku: "A", name: "Alpha", price: Decimal.new("1.00")})

      assert [alpha, beta] = Catalog.list_products()
      assert ["Alpha", "Beta"] = Enum.map([alpha, beta], & &1.name)
      assert Decimal.equal?(alpha.price, Decimal.new("1.00"))
      assert Decimal.equal?(beta.price, Decimal.new("2.00"))
    end

    test "returns an empty list when there are no products" do
      assert [] = Catalog.list_products()
    end
  end

  describe "get_product!/1" do
    test "returns the product" do
      {:ok, product} =
        Catalog.create_product(%{sku: "G-01", name: "Gula", price: Decimal.new("3.00")})

      fetched = Catalog.get_product!(product.id)
      assert fetched.id == product.id
      assert Decimal.equal?(fetched.price, Decimal.new("3.00"))
    end

    test "raises when the product does not exist" do
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_product!(-1) end
    end
  end
end
