defmodule Alur.Contacts.Contact do
  @moduledoc """
  A person the signed-in account keeps in touch with.

  Every contact belongs to exactly one `Alur.Accounts.Account`, and accounts
  never share contacts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Alur.Accounts.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contacts" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :company, :string
    field :notes, :string

    belongs_to :account, Account

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating or updating a contact.

  Only the contact's own fields are cast — the owning `account_id` is set by
  the Contacts context and can never be changed through a form.
  """
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :email, :phone, :company, :notes])
    |> validate_required([:name])
    |> validate_length(:name, max: 120, message: "should be at most 120 character(s)")
    |> validate_email_when_present()
  end

  defp validate_email_when_present(changeset) do
    case get_field(changeset, :email) do
      email when email in [nil, ""] ->
        changeset

      _ ->
        validate_format(changeset, :email, ~r/^[^\s]+@[^\s]+$/,
          message: "must have the @ sign and no spaces"
        )
    end
  end
end
