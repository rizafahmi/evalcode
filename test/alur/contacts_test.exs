defmodule Alur.ContactsTest do
  use Alur.DataCase, async: false

  alias Alur.Accounts
  alias Alur.Contacts
  alias Alur.Contacts.Contact

  @password "super secret 1234"

  defp account!(attrs \\ %{}) do
    email = attrs[:email] || "owner-#{System.unique_integer([:positive])}@example.com"

    {:ok, account} =
      Accounts.register_account(%{
        email: email,
        password: @password,
        password_confirmation: @password
      })

    account
  end

  defp contact_attrs(overrides \\ %{}) do
    Enum.into(overrides, %{
      name: "Sari Wijaya",
      email: "sari@example.com",
      phone: "+62 812 3456 7890",
      company: "Acme",
      notes: "Met at the Jakarta meetup."
    })
  end

  describe "create_contact/2" do
    test "creates a contact owned by the given account" do
      account = account!()

      assert {:ok, %Contact{} = contact} = Contacts.create_contact(account, contact_attrs())
      assert contact.account_id == account.id
      assert contact.name == "Sari Wijaya"
      assert contact.email == "sari@example.com"
    end

    test "requires a name but lets every other field stay blank" do
      account = account!()

      assert {:error, changeset} = Contacts.create_contact(account, %{})
      assert "can't be blank" in errors_on(changeset).name

      assert {:ok, %Contact{email: nil, company: nil, phone: nil, notes: nil}} =
               Contacts.create_contact(account, %{name: "Only A Name"})
    end

    test "rejects a malformed email when one is provided" do
      account = account!()

      assert {:error, changeset} =
               Contacts.create_contact(account, %{name: "Sari", email: "not-an-email"})

      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end
  end

  describe "list_contacts/2" do
    setup do
      account = account!()

      {:ok, %Contact{name: "Sari Wijaya"}} =
        Contacts.create_contact(account, %{name: "Sari Wijaya", company: "Acme"})

      {:ok, %Contact{name: "Bambang Nugroho"}} =
        Contacts.create_contact(account, %{name: "Bambang Nugroho", company: "Nusantara"})

      %{account: account}
    end

    test "returns only the given account's contacts, ordered by name", %{account: account} do
      other = account!()
      {:ok, %Contact{name: "Outsider"}} = Contacts.create_contact(other, %{name: "Outsider"})

      names = Enum.map(Contacts.list_contacts(account), & &1.name)
      assert names == ["Bambang Nugroho", "Sari Wijaya"]
      assert [%Contact{name: "Outsider"}] = Contacts.list_contacts(other)
    end

    test "filters by a case-insensitive substring of the name", %{account: account} do
      assert [%Contact{name: "Sari Wijaya"}] = Contacts.list_contacts(account, "sari")
      assert [%Contact{name: "Bambang Nugroho"}] = Contacts.list_contacts(account, "BAMBANG")
      assert [%Contact{name: "Sari Wijaya"}] = Contacts.list_contacts(account, "WIJ")
      assert length(Contacts.list_contacts(account, "")) == 2
      assert Contacts.list_contacts(account, "   ") == Contacts.list_contacts(account)
    end

    test "only searches the name, not company or email", %{account: account} do
      assert Contacts.list_contacts(account, "acme") == []
      assert Contacts.list_contacts(account, "nusantara") == []
    end
  end

  describe "get_contact/2, update_contact/2, delete_contact/1" do
    test "get_contact returns nil for a foreign account's contact or an unknown id" do
      account = account!()
      other = account!()
      {:ok, contact} = Contacts.create_contact(account, %{name: "Sari"})

      assert %Contact{name: "Sari"} = Contacts.get_contact(account, contact.id)
      assert Contacts.get_contact(other, contact.id) == nil
      assert Contacts.get_contact(account, Ecto.UUID.generate()) == nil
    end

    test "update_contact edits editable fields and never the owner" do
      account = account!()
      {:ok, contact} = Contacts.create_contact(account, %{name: "Sari", company: "Acme"})

      assert {:ok, updated} =
               Contacts.update_contact(contact, %{name: "Sari Wijaya", company: "PT Acme"})

      assert updated.name == "Sari Wijaya"
      assert updated.company == "PT Acme"
      assert updated.account_id == account.id
    end

    test "update_contact validates the new data" do
      account = account!()
      {:ok, contact} = Contacts.create_contact(account, %{name: "Sari"})

      assert {:error, changeset} = Contacts.update_contact(contact, %{name: ""})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "delete_contact removes the contact from the account's list" do
      account = account!()
      {:ok, contact} = Contacts.create_contact(account, %{name: "Sari"})

      assert {:ok, %Contact{}} = Contacts.delete_contact(contact)
      assert Contacts.list_contacts(account) == []
    end
  end
end
