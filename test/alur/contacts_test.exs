defmodule Alur.ContactsTest do
  use Alur.DataCase

  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.Contacts
  alias Alur.Contacts.Contact
  alias Alur.ContactsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    other_user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    other_scope = Scope.for_user(other_user)

    %{scope: scope, other_scope: other_scope, user: user, other_user: other_user}
  end

  describe "list_contacts/2" do
    test "returns contacts belonging to the scoped user only", %{
      scope: scope,
      other_scope: other_scope
    } do
      contact1 = ContactsFixtures.contact_fixture(scope, %{name: "Alice Johnson"})
      contact2 = ContactsFixtures.contact_fixture(scope, %{name: "Bob Smith"})
      _other_contact = ContactsFixtures.contact_fixture(other_scope, %{name: "Charlie Brown"})

      contacts = Contacts.list_contacts(scope)
      contact_ids = Enum.map(contacts, & &1.id)

      assert length(contacts) == 2
      assert contact1.id in contact_ids
      assert contact2.id in contact_ids
    end

    test "filters contacts by search query matching name", %{scope: scope} do
      contact1 = ContactsFixtures.contact_fixture(scope, %{name: "Siti Rahma"})
      _contact2 = ContactsFixtures.contact_fixture(scope, %{name: "Budi Santoso"})

      results = Contacts.list_contacts(scope, %{"search" => "Rahma"})
      assert length(results) == 1
      assert hd(results).id == contact1.id

      # Case-insensitive substring
      results_case = Contacts.list_contacts(scope, %{"query" => "rahma"})
      assert length(results_case) == 1
      assert hd(results_case).id == contact1.id

      # Direct string argument
      results_str = Contacts.list_contacts(scope, "budi")
      assert length(results_str) == 1
      assert hd(results_str).name == "Budi Santoso"
    end
  end

  describe "get_contact!/2 and get_contact/2" do
    test "returns the contact when owned by scoped user", %{scope: scope} do
      contact = ContactsFixtures.contact_fixture(scope)
      assert Contacts.get_contact!(scope, contact.id).id == contact.id
      assert {:ok, fetched} = Contacts.get_contact(scope, contact.id)
      assert fetched.id == contact.id
    end

    test "raises or returns not_found when contact belongs to another user", %{
      scope: scope,
      other_scope: other_scope
    } do
      other_contact = ContactsFixtures.contact_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        Contacts.get_contact!(scope, other_contact.id)
      end

      assert {:error, :not_found} = Contacts.get_contact(scope, other_contact.id)
    end
  end

  describe "create_contact/2" do
    test "creates contact with valid attributes", %{scope: scope} do
      valid_attrs = %{
        name: "Dewi Lestari",
        email: "dewi@example.com",
        phone: "+62811223344",
        company: "Nusantara Tech",
        notes: "Key executive contact"
      }

      assert {:ok, %Contact{} = contact} = Contacts.create_contact(scope, valid_attrs)
      assert contact.name == "Dewi Lestari"
      assert contact.email == "dewi@example.com"
      assert contact.phone == "+62811223344"
      assert contact.company == "Nusantara Tech"
      assert contact.notes == "Key executive contact"
      assert contact.user_id == scope.user.id
    end

    test "fails when name is missing", %{scope: scope} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Contacts.create_contact(scope, %{name: nil})

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_contact/3" do
    test "updates contact with valid attributes", %{scope: scope} do
      contact = ContactsFixtures.contact_fixture(scope)

      assert {:ok, %Contact{} = updated} =
               Contacts.update_contact(scope, contact, %{
                 name: "Updated Name",
                 company: "Updated Co"
               })

      assert updated.name == "Updated Name"
      assert updated.company == "Updated Co"
    end

    test "returns error changeset when attributes are invalid", %{scope: scope} do
      contact = ContactsFixtures.contact_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Contacts.update_contact(scope, contact, %{name: ""})
    end
  end

  describe "delete_contact/2" do
    test "deletes the contact", %{scope: scope} do
      contact = ContactsFixtures.contact_fixture(scope)
      assert {:ok, %Contact{}} = Contacts.delete_contact(scope, contact)

      assert_raise Ecto.NoResultsError, fn ->
        Contacts.get_contact!(scope, contact.id)
      end
    end
  end

  describe "change_contact/3" do
    test "returns changeset", %{scope: scope} do
      contact = ContactsFixtures.contact_fixture(scope)
      assert %Ecto.Changeset{} = Contacts.change_contact(scope, contact)
    end
  end
end
