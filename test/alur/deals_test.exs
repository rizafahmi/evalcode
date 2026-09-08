defmodule Alur.DealsTest do
  use Alur.DataCase

  alias Alur.Contacts
  alias Alur.Deals

  import Alur.AccountsFixtures

  test "creates, updates, lists, and deletes deals with pipeline columns" do
    scope = user_scope_fixture()
    {:ok, contact} = Contacts.create_contact(scope, %{name: "Ada Lovelace"})

    assert Enum.map(Deals.list_pipeline_columns(), & &1.id) == [
             "lead",
             "meeting",
             "proposal",
             "won",
             "lost"
           ]

    assert {:ok, deal} =
             Deals.create_deal(scope, %{
               "title" => "Website redesign",
               "amount" => "15000000",
               "contact_id" => contact.id,
               "pipeline_column_id" => "lead"
             })

    assert Deals.format_idr(deal.amount) == "Rp 15.000.000"
    assert [listed] = Deals.list_contact_deals(scope, contact.id)
    assert listed.id == deal.id

    assert {:ok, updated} =
             Deals.update_deal(scope, deal, %{
               "title" => "Website redesign v2",
               "amount" => "20000000",
               "contact_id" => contact.id,
               "pipeline_column_id" => "meeting"
             })

    assert Deals.get_deal(scope, updated.id).pipeline_column.id == "meeting"
    assert {:ok, _} = Deals.delete_deal(scope, updated)
    assert [] = Deals.list_contact_deals(scope, contact.id)
  end

  test "deals are isolated between accounts and contacts" do
    first_scope = user_scope_fixture()
    second_scope = user_scope_fixture()
    {:ok, contact} = Contacts.create_contact(first_scope, %{name: "Private contact"})

    assert {:ok, deal} =
             Deals.create_deal(first_scope, %{
               title: "Private deal",
               amount: 100,
               contact_id: contact.id,
               pipeline_column_id: "lead"
             })

    refute Deals.get_deal(second_scope, deal.id)
    assert [] = Deals.list_contact_deals(second_scope, contact.id)

    assert {:error, :not_found} =
             Deals.create_deal(second_scope, %{
               title: "Cross-account deal",
               amount: 100,
               contact_id: contact.id,
               pipeline_column_id: "lead"
             })
  end

  test "title, amount, contact, and pipeline column are required" do
    changeset = Deals.Deal.changeset(%Deals.Deal{}, %{})
    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.title == ["can't be blank"]
    assert errors.amount == ["can't be blank"]
    assert errors.contact_id == ["can't be blank"]
    assert errors.pipeline_column_id == ["can't be blank"]
  end

  test "records creation, movement, and notes newest first" do
    scope = user_scope_fixture()
    {:ok, contact} = Contacts.create_contact(scope, %{name: "Activity contact"})

    {:ok, deal} =
      Deals.create_deal(scope, %{
        title: "Activity deal",
        amount: 100,
        contact_id: contact.id,
        pipeline_column_id: "lead"
      })

    assert {:ok, deal} = Deals.move_deal(scope, deal, "meeting")

    assert {:ok, _note} =
             Deals.create_activity(scope, deal, %{description: "Spoke with the buyer."})

    activities = Deals.list_deal_activities(scope, deal.id)

    assert Enum.map(activities, & &1.description) == [
             "Spoke with the buyer.",
             "Moved from Lead to Meeting.",
             "Deal created in Lead."
           ]
  end

  test "activity entries are isolated to the deal account" do
    first_scope = user_scope_fixture()
    second_scope = user_scope_fixture()
    {:ok, contact} = Contacts.create_contact(first_scope, %{name: "Private contact"})

    {:ok, deal} =
      Deals.create_deal(first_scope, %{
        title: "Private activity deal",
        amount: 100,
        contact_id: contact.id,
        pipeline_column_id: "lead"
      })

    assert Deals.list_deal_activities(second_scope, deal.id) == []

    assert {:error, :not_found} =
             Deals.create_activity(second_scope, deal, %{description: "No access"})
  end

  test "next actions are account scoped, sortable, and logged when completed" do
    scope = user_scope_fixture()
    {:ok, contact} = Contacts.create_contact(scope, %{name: "Follow-up contact"})

    {:ok, deal} =
      Deals.create_deal(scope, %{
        title: "Follow-up deal",
        amount: 100,
        contact_id: contact.id,
        pipeline_column_id: "lead"
      })

    yesterday = Date.add(Date.utc_today(), -1) |> Date.to_iso8601()

    assert {:ok, action} =
             Deals.create_next_action(scope, deal, %{
               description: "Call the buyer",
               due_date: yesterday
             })

    assert Deals.overdue?(action)

    assert Deals.format_next_action_due(action) ==
             Calendar.strftime(Date.add(Date.utc_today(), -1), "%d %b %Y")

    assert [listed] = Deals.list_open_next_actions(scope)
    assert listed.id == action.id
    assert listed.deal.title == "Follow-up deal"

    assert {:ok, completed} = Deals.complete_next_action(scope, action)
    assert completed.done
    assert Deals.list_open_next_actions(scope) == []

    assert Enum.any?(
             Deals.list_deal_activities(scope, deal.id),
             &(&1.description == "Follow-up added: Call the buyer.")
           )

    assert Enum.any?(
             Deals.list_deal_activities(scope, deal.id),
             &(&1.description == "Follow-up completed: Call the buyer.")
           )
  end
end
