defmodule AlurWeb.ContactsLiveTest do
  use AlurWeb.ConnCase

  import Phoenix.LiveViewTest
  import Alur.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "lists, searches, opens, edits, and deletes a contact", %{conn: conn, user: user} do
    scope = user_scope_fixture(user)

    {:ok, contact} =
      Alur.Contacts.create_contact(scope, %{
        name: "Ada Lovelace",
        email: "ada@example.com",
        company: "Analytical Engines"
      })

    {:ok, list_lv, list_html} = live(conn, ~p"/contacts")
    assert list_html =~ "Ada Lovelace"

    search_html =
      list_lv
      |> element("#contact-search")
      |> render_change(%{"search" => "Ada"})

    assert search_html =~ "Ada Lovelace"

    {:ok, detail_lv, detail_html} = live(conn, ~p"/contacts/#{contact.id}")
    assert detail_html =~ "Analytical Engines"

    {:ok, edit_lv, _html} = live(conn, ~p"/contacts/#{contact.id}/edit")

    assert {:error, {:live_redirect, %{to: path}}} =
             edit_lv
             |> form("#contact-form", contact: %{name: "Ada Byron"})
             |> render_submit()

    assert path == ~p"/contacts/#{contact.id}"
    assert Alur.Contacts.get_contact(scope, contact.id).name == "Ada Byron"

    assert {:error, {:live_redirect, %{to: "/contacts"}}} =
             detail_lv
             |> element("button", "Delete")
             |> render_click()
  end

  test "creates, moves, displays, and deletes a deal from a contact", %{conn: conn, user: user} do
    scope = user_scope_fixture(user)

    {:ok, contact} = Alur.Contacts.create_contact(scope, %{name: "Grace Hopper"})
    {:ok, new_lv, new_html} = live(conn, ~p"/contacts/#{contact.id}/deals/new")
    assert new_html =~ "New deal"

    assert {:error, {:live_redirect, %{to: deal_path}}} =
             new_lv
             |> form("#deal-form",
               deal: %{
                 title: "Compiler contract",
                 amount: "15000000",
                 contact_id: contact.id,
                 pipeline_column_id: "lead"
               }
             )
             |> render_submit()

    assert deal_path =~ "/deals/"
    deal_id = deal_path |> String.split("/") |> List.last()
    {:ok, deal_lv, deal_html} = live(conn, deal_path)
    assert deal_html =~ "Rp 15.000.000"
    assert deal_html =~ "Lead"
    assert deal_html =~ "Deal created in Lead."

    assert deal_lv
           |> form("#activity-form", activity: %{description: "Discussed timeline with Grace."})
           |> render_submit() =~ "Discussed timeline with Grace."

    assert {:error, {:live_redirect, %{to: edit_path}}} =
             deal_lv
             |> element("a", "Edit")
             |> render_click()

    {:ok, edit_lv, _html} = live(conn, edit_path)

    assert {:error, {:live_redirect, %{to: ^deal_path}}} =
             edit_lv
             |> form("#deal-form",
               deal: %{
                 title: "Compiler contract",
                 amount: "15000000",
                 contact_id: contact.id,
                 pipeline_column_id: "won"
               }
             )
             |> render_submit()

    assert Alur.Deals.get_deal(scope, deal_id).pipeline_column.id == "won"
    {:ok, _contact_lv, contact_html} = live(conn, ~p"/contacts/#{contact.id}")
    assert contact_html =~ "Compiler contract"
    assert contact_html =~ "Rp 15.000.000"
    contact_path = ~p"/contacts/#{contact.id}"
    {:ok, delete_lv, _delete_html} = live(conn, deal_path)

    assert {:error, {:live_redirect, %{to: ^contact_path}}} =
             delete_lv
             |> element("button", "Delete")
             |> render_click()

    refute Alur.Deals.get_deal(scope, deal_id)
    assert {:ok, _contact_lv, _contact_html} = live(conn, contact_path)
  end

  test "adds and completes a follow-up from the deal and todo pages", %{conn: conn, user: user} do
    scope = user_scope_fixture(user)
    {:ok, contact} = Alur.Contacts.create_contact(scope, %{name: "Follow-up person"})

    {:ok, deal} =
      Alur.Deals.create_deal(scope, %{
        title: "Follow-up opportunity",
        amount: 100,
        contact_id: contact.id,
        pipeline_column_id: "lead"
      })

    {:ok, deal_lv, deal_html} = live(conn, ~p"/deals/#{deal.id}")
    refute deal_html =~ "Call the buyer"

    yesterday = Date.add(Date.utc_today(), -1) |> Date.to_iso8601()

    assert deal_lv
           |> form("#next-action-form",
             next_action: %{description: "Call the buyer", due_date: yesterday, due_time: "10:30"}
           )
           |> render_submit() =~ "Call the buyer"

    {:ok, todo_lv, todo_html} = live(conn, ~p"/todos")
    assert todo_html =~ "Call the buyer"
    assert todo_html =~ "Follow-up opportunity"
    assert todo_html =~ "OVERDUE"

    [action] = Alur.Deals.list_open_next_actions(scope)

    assert todo_lv
           |> element("button[phx-value-id='#{action.id}']")
           |> render_click() =~ "All clear"

    {:ok, _deal_lv, deal_html} = live(conn, ~p"/deals/#{deal.id}")
    assert deal_html =~ "Follow-up added: Call the buyer."
    assert deal_html =~ "Follow-up completed: Call the buyer."
  end
end
