defmodule Alur.DealsTest do
  use Alur.DataCase, async: false

  alias Alur.Accounts
  alias Alur.Activities
  alias Alur.Contacts
  alias Alur.Deals
  alias Alur.Deals.Deal

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

  defp contact!(account, attrs \\ %{}) do
    {:ok, contact} = Contacts.create_contact(account, Map.merge(%{name: "Sari Wijaya"}, attrs))
    contact
  end

  defp column!(name) do
    Enum.find(Deals.list_pipeline_columns(), &(&1.name == name))
  end

  defp deal_attrs(overrides \\ %{}) do
    Enum.into(overrides, %{
      title: "Website redesign",
      amount: 15_000_000,
      notes: "Quoted for the full relaunch.",
      pipeline_column_id: column!("Lead").id
    })
  end

  describe "list_pipeline_columns/0" do
    test "returns the seeded starting set in board order" do
      assert Enum.map(Deals.list_pipeline_columns(), & &1.name) ==
               ["Lead", "Meeting", "Proposal", "Won", "Lost"]

      assert Enum.map(Deals.list_pipeline_columns(), & &1.order) == [1, 2, 3, 4, 5]
    end
  end

  describe "create_deal/3" do
    test "creates a deal owned by the account and anchored to the contact" do
      account = account!()
      contact = contact!(account)

      assert {:ok, %Deal{} = deal} = Deals.create_deal(account, contact, deal_attrs())

      assert deal.account_id == account.id
      assert deal.contact_id == contact.id
      assert deal.title == "Website redesign"
      assert deal.amount == 15_000_000
      assert deal.notes == "Quoted for the full relaunch."
      assert deal.pipeline_column_id == column!("Lead").id
    end

    test "requires a title, an amount, and a pipeline column, but lets notes stay blank" do
      account = account!()
      contact = contact!(account)

      assert {:error, changeset} = Deals.create_deal(account, contact, %{})
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).pipeline_column_id

      assert {:ok, %Deal{notes: nil}} =
               Deals.create_deal(account, contact, %{
                 title: "Logo refresh",
                 amount: 5_000_000,
                 pipeline_column_id: column!("Lead").id
               })
    end

    test "rejects a negative amount" do
      account = account!()
      contact = contact!(account)

      assert {:error, changeset} =
               Deals.create_deal(account, contact, %{
                 title: "Bad deal",
                 amount: -1,
                 pipeline_column_id: column!("Lead").id
               })

      assert errors_on(changeset).amount != []
    end

    test "ignores any account_id or contact_id smuggled through the attrs" do
      account = account!()
      contact = contact!(account)
      other = account!()
      other_contact = contact!(other)

      assert {:ok, %Deal{} = deal} =
               Deals.create_deal(
                 account,
                 contact,
                 deal_attrs(%{
                   account_id: other.id,
                   contact_id: other_contact.id
                 })
               )

      assert deal.account_id == account.id
      assert deal.contact_id == contact.id
    end
  end

  describe "list_contact_deals/2" do
    test "returns only the given account's deals for the given contact, newest first" do
      account = account!()
      contact = contact!(account)
      {:ok, _first} = Deals.create_deal(account, contact, deal_attrs(%{title: "First"}))
      Process.sleep(1100)
      {:ok, _second} = Deals.create_deal(account, contact, deal_attrs(%{title: "Second"}))

      other_account = account!()
      other_contact = contact!(other_account)

      {:ok, _foreign} =
        Deals.create_deal(other_account, other_contact, deal_attrs(%{title: "Not yours"}))

      # The other account's deal never shows up for this account…
      assert [%Deal{title: "Second"}, %Deal{title: "First"}] =
               Deals.list_contact_deals(account, contact.id)

      # …and this account's deals never show up for the other account.
      assert [%Deal{title: "Not yours"}] =
               Deals.list_contact_deals(other_account, other_contact.id)

      assert Deals.list_contact_deals(account, other_contact.id) == []
    end

    test "preloads the contact and pipeline column on every deal" do
      account = account!()
      contact = contact!(account)
      {:ok, _deal} = Deals.create_deal(account, contact, deal_attrs())

      assert [%Deal{contact: %{name: "Sari Wijaya"}, pipeline_column: %{name: "Lead"}}] =
               Deals.list_contact_deals(account, contact.id)
    end
  end

  describe "list_deals/1" do
    test "returns only the given account's deals, newest first, across all columns" do
      account = account!()
      contact = contact!(account)

      {:ok, _older} =
        Deals.create_deal(account, contact, deal_attrs(%{title: "Older", amount: 10_000_000}))

      Process.sleep(1100)

      {:ok, _newer} =
        Deals.create_deal(
          account,
          contact,
          deal_attrs(%{title: "Newer", pipeline_column_id: column!("Meeting").id})
        )

      other_account = account!()
      other_contact = contact!(other_account)

      {:ok, _foreign} =
        Deals.create_deal(other_account, other_contact, deal_attrs(%{title: "Not yours"}))

      # The other account's deals never show up for this account…
      assert [%Deal{title: "Newer"}, %Deal{title: "Older"}] = Deals.list_deals(account)

      # …and vice versa.
      assert [%Deal{title: "Not yours"}] = Deals.list_deals(other_account)
    end

    test "preloads the contact and pipeline column on every deal" do
      account = account!()
      contact = contact!(account)
      {:ok, _deal} = Deals.create_deal(account, contact, deal_attrs())

      assert [
               %Deal{contact: %{name: "Sari Wijaya"}, pipeline_column: %{name: "Lead"}}
             ] = Deals.list_deals(account)
    end
  end

  describe "move_deal/3" do
    test "moves a deal to another column and keeps its owner and anchor" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert {:ok, moved} = Deals.move_deal(account, deal.id, column!("Meeting").id)

      assert moved.id == deal.id
      assert moved.pipeline_column_id == column!("Meeting").id
      assert moved.account_id == account.id
      assert moved.contact_id == contact.id

      # The move persists.
      assert %Deal{pipeline_column: %{name: "Meeting"}} = Deals.get_deal(account, deal.id)
    end

    test "can move a deal all the way to Won or Lost" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert {:ok, _deal} = Deals.move_deal(account, deal.id, column!("Won").id)
      assert {:ok, _deal} = Deals.move_deal(account, deal.id, column!("Lost").id)
      assert %Deal{pipeline_column: %{name: "Lost"}} = Deals.get_deal(account, deal.id)
    end

    test "refuses an unknown deal or another account's deal, leaving it untouched" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())
      other = account!()

      assert {:error, :not_found} =
               Deals.move_deal(account, Ecto.UUID.generate(), column!("Meeting").id)

      assert {:error, :not_found} = Deals.move_deal(other, deal.id, column!("Meeting").id)

      assert %Deal{pipeline_column: %{name: "Lead"}} = Deals.get_deal(account, deal.id)
    end

    test "refuses an unknown target column, leaving the deal untouched" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert {:error, :not_found} = Deals.move_deal(account, deal.id, Ecto.UUID.generate())
      assert %Deal{pipeline_column: %{name: "Lead"}} = Deals.get_deal(account, deal.id)
    end
  end

  describe "get_deal/2" do
    test "returns the owner's deal with contact and column preloaded" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert %Deal{title: "Website redesign"} = Deals.get_deal(account, deal.id)
      assert %Deal{contact: %{name: "Sari Wijaya"}} = Deals.get_deal(account, deal.id)
      assert %Deal{pipeline_column: %{name: "Lead"}} = Deals.get_deal(account, deal.id)
    end

    test "returns nil for a foreign account's deal or an unknown id" do
      account = account!()
      other = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert Deals.get_deal(other, deal.id) == nil
      assert Deals.get_deal(account, Ecto.UUID.generate()) == nil
    end
  end

  describe "update_deal/2 and delete_deal/1" do
    test "updates editable fields and never the owner or anchor" do
      account = account!()
      contact = contact!(account)
      other = account!()
      other_contact = contact!(other)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert {:ok, updated} =
               Deals.update_deal(deal, %{
                 title: "Website redesign v2",
                 amount: 25_000_000,
                 notes: "",
                 pipeline_column_id: column!("Meeting").id,
                 account_id: other.id,
                 contact_id: other_contact.id
               })

      assert updated.title == "Website redesign v2"
      assert updated.amount == 25_000_000
      assert updated.pipeline_column_id == column!("Meeting").id
      assert updated.account_id == account.id
      assert updated.contact_id == contact.id
    end

    test "update_deal still validates the new data" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert {:error, changeset} = Deals.update_deal(deal, %{title: ""})
      assert "can't be blank" in errors_on(changeset).title
    end

    test "delete_deal removes the deal from the contact's list" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert {:ok, %Deal{}} = Deals.delete_deal(deal)
      assert Deals.list_contact_deals(account, contact.id) == []
    end
  end

  describe "deleting a contact" do
    test "removes that contact's deals too, so no orphaned deals survive" do
      account = account!()
      contact = contact!(account)
      {:ok, _deal} = Deals.create_deal(account, contact, deal_attrs())

      assert {:ok, _contact} = Contacts.delete_contact(contact)
      assert Deals.list_contact_deals(account, contact.id) == []

      assert Alur.Repo.all(from d in Deal, where: d.account_id == ^account.id) == []
    end
  end

  describe "activity log lines are written for deal events" do
    test "creating a deal writes a 'Deal created' line on its log" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == ["Deal created"]
    end

    test "move_deal writes a move line naming the old and new columns" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert {:ok, _moved} = Deals.move_deal(account, deal.id, column!("Meeting").id)

      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == [
               "Moved from Lead to Meeting",
               "Deal created"
             ]
    end

    test "several moves append one line each, newest first" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert {:ok, _} = Deals.move_deal(account, deal.id, column!("Meeting").id)
      assert {:ok, _} = Deals.move_deal(account, deal.id, column!("Won").id)

      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == [
               "Moved from Meeting to Won",
               "Moved from Lead to Meeting",
               "Deal created"
             ]
    end

    test "moving to the column the deal is already on writes nothing" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      assert {:ok, _same} = Deals.move_deal(account, deal.id, column!("Lead").id)
      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == ["Deal created"]
    end

    test "refused moves never write a line" do
      account = account!()
      other = account!()
      contact = contact!(account)
      other_contact = contact!(other)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())
      {:ok, _foreign_deal} = Deals.create_deal(other, other_contact, deal_attrs())

      assert {:error, :not_found} = Deals.move_deal(other, deal.id, column!("Meeting").id)

      assert {:error, :not_found} =
               Deals.move_deal(account, Ecto.UUID.generate(), column!("Meeting").id)

      assert {:error, :not_found} = Deals.move_deal(account, deal.id, Ecto.UUID.generate())

      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == ["Deal created"]
    end

    test "update_deal writes a move line when the column changes but not for other edits" do
      account = account!()
      contact = contact!(account)
      {:ok, deal} = Deals.create_deal(account, contact, deal_attrs())

      # Editing fields while keeping the column writes nothing new…
      assert {:ok, _updated} = Deals.update_deal(deal, %{title: "Website redesign v2"})
      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == ["Deal created"]

      # …and re-submitting the very same column writes nothing either.
      assert {:ok, _updated} = Deals.update_deal(deal, %{pipeline_column_id: column!("Lead").id})
      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == ["Deal created"]

      # Changing the column through the edit path logs the move like a drag does.
      assert {:ok, _updated} =
               Deals.update_deal(deal, %{pipeline_column_id: column!("Meeting").id})

      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == [
               "Moved from Lead to Meeting",
               "Deal created"
             ]
    end
  end

  describe "format_idr/1" do
    test "formats whole rupiah amounts with Indonesian grouping" do
      assert Deals.format_idr(15_000_000) == "Rp 15.000.000"
      assert Deals.format_idr(0) == "Rp 0"
      assert Deals.format_idr(1_000) == "Rp 1.000"
      assert Deals.format_idr(1_000_000_000) == "Rp 1.000.000.000"
      assert Deals.format_idr(999) == "Rp 999"
    end

    test "renders a dash for a missing amount" do
      assert Deals.format_idr(nil) == "—"
    end
  end
end
