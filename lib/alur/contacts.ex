defmodule Alur.Contacts do
  @moduledoc """
  The Contacts context.

  All operations require an authenticated `Scope` as the first argument,
  ensuring strict isolation between user accounts.
  """

  import Ecto.Query, warn: false
  alias Alur.Accounts.Scope
  alias Alur.Accounts.User
  alias Alur.Contacts.Contact
  alias Alur.Repo

  @doc """
  Returns the list of contacts for the scoped user.

  Supports filtering by name using a query string or map containing "query" or "search".
  Results are ordered alphabetically by name.
  """
  def list_contacts(%Scope{user: %User{id: user_id}}, params \\ %{}) do
    query =
      from c in Contact,
        where: c.user_id == ^user_id,
        order_by: [asc: c.name]

    search_term = extract_search_term(params)

    query =
      if search_term != "" do
        pattern = "%#{search_term}%"
        from c in query, where: like(c.name, ^pattern)
      else
        query
      end

    Repo.all(query)
  end

  defp extract_search_term(term) when is_binary(term), do: String.trim(term)
  defp extract_search_term(%{"search" => term}) when is_binary(term), do: String.trim(term)
  defp extract_search_term(%{"query" => term}) when is_binary(term), do: String.trim(term)
  defp extract_search_term(%{search: term}) when is_binary(term), do: String.trim(term)
  defp extract_search_term(%{query: term}) when is_binary(term), do: String.trim(term)
  defp extract_search_term(_), do: ""

  @doc """
  Gets a single contact for the scoped user.

  Raises `Ecto.NoResultsError` if the Contact does not exist or does not belong to the user.
  """
  def get_contact!(%Scope{user: %User{id: user_id}}, id) do
    Repo.get_by!(Contact, id: id, user_id: user_id)
  end

  @doc """
  Gets a single contact for the scoped user, returning `{:ok, contact}` or `{:error, :not_found}`.
  """
  def get_contact(%Scope{user: %User{id: user_id}}, id) do
    case Repo.get_by(Contact, id: id, user_id: user_id) do
      nil -> {:error, :not_found}
      %Contact{} = contact -> {:ok, contact}
    end
  end

  @doc """
  Creates a contact belonging to the scoped user.
  """
  def create_contact(%Scope{user: %User{id: user_id}}, attrs \\ %{}) do
    %Contact{user_id: user_id}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a contact if it belongs to the scoped user.
  """
  def update_contact(
        %Scope{user: %User{id: user_id}},
        %Contact{user_id: user_id} = contact,
        attrs
      ) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a contact if it belongs to the scoped user.
  """
  def delete_contact(%Scope{user: %User{id: user_id}}, %Contact{user_id: user_id} = contact) do
    Repo.delete(contact)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking contact changes.
  """
  def change_contact(%Scope{}, %Contact{} = contact, attrs \\ %{}) do
    Contact.changeset(contact, attrs)
  end
end
