defmodule Alur.ContactsTest do
  use Alur.DataCase

  alias Alur.Contacts

  import Alur.AccountsFixtures

  test "creates, updates, lists, and deletes contacts within an account" do
    user = user_fixture()
    scope = user_scope_fixture(user)

    assert {:ok, contact} =
             Contacts.create_contact(scope, %{
               name: "Ada Lovelace",
               email: "ada@example.com",
               company: "Analytical Engines"
             })

    assert [^contact] = Contacts.list_contacts(scope)
    assert [^contact] = Contacts.list_contacts(scope, "ada")
    assert [] = Contacts.list_contacts(scope, "grace")

    assert {:ok, updated} = Contacts.update_contact(scope, contact, %{name: "Ada Byron"})
    assert updated.name == "Ada Byron"
    assert {:ok, _} = Contacts.delete_contact(scope, updated)
    assert [] = Contacts.list_contacts(scope)
  end

  test "contacts are isolated between accounts" do
    first_scope = user_scope_fixture()
    second_scope = user_scope_fixture()
    {:ok, contact} = Contacts.create_contact(first_scope, %{name: "Private contact"})

    assert Contacts.get_contact(first_scope, contact.id)
    refute Contacts.get_contact(second_scope, contact.id)
    assert [] = Contacts.list_contacts(second_scope)

    assert {:error, :not_found} =
             Contacts.update_contact(second_scope, contact, %{name: "Changed"})

    assert {:error, :not_found} = Contacts.delete_contact(second_scope, contact)
  end

  test "name is required" do
    changeset = Contacts.change_contact(user_scope_fixture())
    refute changeset.valid?
    assert %{name: ["can't be blank"]} = errors_on(changeset)
  end
end
