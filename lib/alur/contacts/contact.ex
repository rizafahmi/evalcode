defmodule Alur.Contacts.Contact do
  @moduledoc "A person managed by an Alur account."

  use Ecto.Schema
  import Ecto.Changeset

  alias Alur.Accounts.User
  alias Alur.Deals.Deal

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contacts" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :company, :string
    field :notes, :string
    belongs_to :user, User
    has_many :deals, Deal
    timestamps(type: :utc_datetime)
  end

  @doc "Builds a changeset for contact creation and updates."
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :email, :phone, :company, :notes])
    |> validate_required(:name)
    |> validate_length(:name, max: 160)
    |> validate_length(:email, max: 160)
    |> validate_length(:phone, max: 80)
    |> validate_length(:company, max: 160)
  end
end
