defmodule Alur.Contacts.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "contacts" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :company, :string
    field :notes, :string

    belongs_to :user, Alur.Accounts.User
    has_many :deals, Alur.Deals.Deal

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a contact.
  """
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :email, :phone, :company, :notes])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:email, max: 255)
    |> validate_length(:phone, max: 50)
    |> validate_length(:company, max: 255)
    |> validate_length(:notes, max: 10_000)
  end
end
