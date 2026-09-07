defmodule Alur.ContactsFixtures do
  @moduledoc """
  Test helpers for creating contacts via the `Alur.Contacts` context.
  """

  alias Alur.Accounts.Scope
  alias Alur.Contacts

  def unique_contact_name, do: "Contact #{System.unique_integer([:positive])}"
  def unique_contact_email, do: "contact#{System.unique_integer([:positive])}@example.com"

  def valid_contact_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_contact_name(),
      email: unique_contact_email(),
      phone: "+62812345678",
      company: "Acme Corp",
      notes: "Met at annual industry summit"
    })
  end

  def contact_fixture(%Scope{} = scope, attrs \\ %{}) do
    {:ok, contact} =
      attrs
      |> valid_contact_attributes()
      |> then(&Contacts.create_contact(scope, &1))

    contact
  end
end
