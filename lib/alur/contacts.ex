defmodule Alur.Contacts do
  @moduledoc """
  The Contacts context manages the contacts a signed-in account keeps track of.

  Every function takes the owning `%Alur.Accounts.Account{}` so one account can
  never list, read, edit, or delete another account's contacts.
  """

  import Ecto.Query, warn: false

  alias Alur.Accounts.Account
  alias Alur.Contacts.Contact
  alias Alur.Repo

  @doc """
  Returns the contacts that belong to `account`, ordered by name.

  When `search` is a non-blank string, only contacts whose name contains it
  (case-insensitively) are returned.
  """
  def list_contacts(%Account{id: account_id}, search \\ "") do
    query =
      from(c in Contact,
        where: c.account_id == ^account_id,
        order_by: [asc: fragment("lower(?)", c.name), asc: c.name]
      )

    case String.trim(search) do
      "" ->
        Repo.all(query)

      term ->
        Repo.all(
          from(c in query,
            where: fragment("instr(lower(?), lower(?)) > 0", c.name, ^term)
          )
        )
    end
  end

  @doc """
  Gets a single contact, but only if it belongs to `account`.

  Returns `nil` when the id is unknown or the contact belongs to another
  account.
  """
  def get_contact(%Account{id: account_id}, id) do
    Repo.get_by(Contact, id: id, account_id: account_id)
  end

  @doc """
  Creates a contact owned by `account`.

  Returns `{:ok, contact}` or `{:error, changeset}`.
  """
  def create_contact(%Account{id: account_id}, attrs \\ %{}) do
    %Contact{account_id: account_id}
    |> change_contact(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates the editable fields of a contact.

  The contact must have been fetched through `get_contact/2` (or an equivalent
  account-scoped query) so ownership is never changed here.
  """
  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> change_contact(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a contact. Same ownership caveat as `update_contact/2`.
  """
  def delete_contact(%Contact{} = contact) do
    Repo.delete(contact)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for a contact form.
  """
  def change_contact(%Contact{} = contact, attrs \\ %{}) do
    Contact.changeset(contact, attrs)
  end
end
