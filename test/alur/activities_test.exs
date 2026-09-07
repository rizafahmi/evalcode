defmodule Alur.ActivitiesTest do
  use Alur.DataCase, async: false

  alias Alur.Accounts
  alias Alur.Activities
  alias Alur.Activities.Activity
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

  defp deal!(account, contact, attrs \\ %{}) do
    {:ok, deal} =
      Deals.create_deal(
        account,
        contact,
        Map.merge(
          %{
            title: "Website redesign",
            amount: 15_000_000,
            pipeline_column_id: column!("Lead").id
          },
          attrs
        )
      )

    deal
  end

  describe "a deal's log" do
    test "creating a deal writes its opening 'Deal created' line, owned by that deal" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      assert [%Activity{description: "Deal created"}] = Activities.list_for_deal(deal)
      assert [%Activity{deal_id: activity_deal_id}] = Activities.list_for_deal(deal)
      assert activity_deal_id == deal.id
      assert %Activity{inserted_at: %DateTime{}} = hd(Activities.list_for_deal(deal))
    end

    test "another deal's lines never appear on this deal's log" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      other =
        deal!(account, contact, %{
          title: "Logo refresh",
          pipeline_column_id: column!("Meeting").id
        })

      {:ok, _line} = Activities.log(other, "Note: only for the other deal")

      assert [%Activity{description: "Deal created"}] = Activities.list_for_deal(deal)
    end
  end

  describe "list_for_deal/1" do
    test "returns every line newest first" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      {:ok, _first} = Activities.log(deal, "Note: oldest")
      {:ok, _second} = Activities.log(deal, "Note: middle")
      {:ok, _third} = Activities.log(deal, "Note: newest")

      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == [
               "Note: newest",
               "Note: middle",
               "Note: oldest",
               "Deal created"
             ]
    end
  end

  describe "log/2" do
    test "writes one line for the deal with the given description and a timestamp" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      assert {:ok, %Activity{description: "Note: called them"} = line} =
               Activities.log(deal, "Note: called them")

      assert line.deal_id == deal.id

      assert %Activity{description: "Note: called them", inserted_at: %DateTime{}} =
               hd(Activities.list_for_deal(deal))
    end

    test "rejects a blank description" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      assert {:error, changeset} = Activities.log(deal, "")
      assert "can't be blank" in errors_on(changeset).description
      assert Activities.list_for_deal(deal) |> length() == 1
    end

    test "rejects a description longer than 500 characters" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      assert {:error, changeset} = Activities.log(deal, String.duplicate("x", 501))
      assert "should be at most 500 character(s)" in errors_on(changeset).description
      assert Activities.list_for_deal(deal) |> length() == 1
    end
  end

  describe "cascading deletes" do
    test "deleting a deal removes its activity log" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)
      {:ok, _line} = Activities.log(deal, "Note: about to disappear")

      assert {:ok, %Deal{}} = Deals.delete_deal(deal)
      assert Activities.list_for_deal(deal) == []
    end

    test "deleting the contact removes its deals and therefore their logs" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)
      {:ok, _line} = Activities.log(deal, "Note: about to disappear")

      assert {:ok, _contact} = Contacts.delete_contact(contact)
      assert Activities.list_for_deal(deal) == []

      assert Alur.Repo.all(from a in Activity, where: a.deal_id == ^deal.id) == []
    end
  end

  describe "format_when/1" do
    test "shows the day and time in Western Indonesia Time (UTC+7)" do
      assert Activities.format_when(~U[2025-01-12 14:05:00Z]) == "12 Jan 2025, 21:05 WIB"
      assert Activities.format_when(~U[2025-01-12 00:30:00Z]) == "12 Jan 2025, 07:30 WIB"
    end

    test "rolls the date over at Jakarta midnight" do
      assert Activities.format_when(~U[2025-12-31 18:30:00Z]) == "01 Jan 2026, 01:30 WIB"
    end
  end
end
