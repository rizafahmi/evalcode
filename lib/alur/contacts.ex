defmodule Alur.Contacts do
  @moduledoc "The Contacts context."

  import Ecto.Query, warn: false

  alias Alur.Accounts.Scope
  alias Alur.Contacts.Contact
  alias Alur.Repo

  @doc "Lists contacts belonging to the current account, optionally filtered by name."
  def list_contacts(%Scope{user: user}, search \\ "") do
    contacts =
      Contact
      |> where([contact], contact.user_id == ^user.id)
      |> order_by([contact], asc: contact.name)
      |> Repo.all()

    case String.trim(search) do
      "" ->
        contacts

      query ->
        Enum.filter(contacts, &String.contains?(String.downcase(&1.name), String.downcase(query)))
    end
  end

  @doc "Gets a contact for the current account."
  def get_contact(%Scope{user: user}, id), do: Repo.get_by(Contact, id: id, user_id: user.id)

  @doc "Creates a contact for the current account."
  def create_contact(%Scope{user: user}, attrs) do
    %Contact{user_id: user.id}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Returns a changeset for an existing contact."
  def change_contact(%Scope{} = scope, %Contact{} = contact, attrs) do
    if contact.user_id == scope.user.id,
      do: Contact.changeset(contact, attrs),
      else: Contact.changeset(%Contact{}, attrs)
  end

  def change_contact(%Scope{} = scope, %Contact{} = contact),
    do: change_contact(scope, contact, %{})

  def change_contact(%Scope{user: user}, attrs),
    do: Contact.changeset(%Contact{user_id: user.id}, attrs)

  @doc "Returns a changeset for a new contact."
  def change_contact(%Scope{user: user}), do: Contact.changeset(%Contact{user_id: user.id}, %{})

  @doc "Updates a contact belonging to the current account."
  def update_contact(%Scope{} = scope, %Contact{} = contact, attrs) do
    if contact.user_id == scope.user.id do
      contact |> Contact.changeset(attrs) |> Repo.update()
    else
      {:error, :not_found}
    end
  end

  @doc "Deletes a contact belonging to the current account."
  def delete_contact(%Scope{} = scope, %Contact{} = contact) do
    if contact.user_id == scope.user.id, do: Repo.delete(contact), else: {:error, :not_found}
  end
end
