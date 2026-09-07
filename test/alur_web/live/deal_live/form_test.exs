defmodule AlurWeb.DealLive.FormTest do
  use AlurWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.ContactsFixtures
  alias Alur.Deals
  alias Alur.DealsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    contact = ContactsFixtures.contact_fixture(scope)
    %{user: user, scope: scope, contact: contact}
  end

  describe "new deal" do
    test "redirects if user is not logged in", %{conn: conn, contact: contact} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/contacts/#{contact}/deals/new")
    end

    test "validates required fields", %{conn: conn, user: user, contact: contact} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/contacts/#{contact}/deals/new")

      html =
        lv
        |> form("#deal-form", deal: %{title: "", amount: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "creates deal from contact and redirects to deal page", %{
      conn: conn,
      user: user,
      contact: contact
    } do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/contacts/#{contact}/deals/new")

      proposal = Deals.get_pipeline_column_by_name("Proposal")

      {:ok, _show_lv, html} =
        lv
        |> form("#deal-form",
          deal: %{
            title: "Hardware Upgrade Contract",
            amount: "75000000",
            pipeline_column_id: proposal.id,
            notes: "Initial proposal delivered to client"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Deal created successfully."
      assert html =~ "Hardware Upgrade Contract"
      assert html =~ "Rp 75.000.000"
      assert html =~ "Proposal"
      assert html =~ contact.name
    end
  end

  describe "edit deal" do
    test "redirects if user is not logged in", %{conn: conn, scope: scope} do
      deal = DealsFixtures.deal_fixture(scope)

      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/deals/#{deal}/edit")
    end

    test "cannot edit another user's deal", %{conn: conn, user: user} do
      other_user = AccountsFixtures.user_fixture()
      other_scope = Scope.for_user(other_user)
      other_deal = DealsFixtures.deal_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        conn
        |> log_in_user(user)
        |> live(~p"/deals/#{other_deal}/edit")
      end
    end

    test "updates deal and redirects to deal page", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      deal = DealsFixtures.deal_fixture(scope, %{title: "Initial Title", amount: 10_000_000})
      won = Deals.get_pipeline_column_by_name("Won")

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/deals/#{deal}/edit")

      {:ok, _show_lv, html} =
        lv
        |> form("#deal-form",
          deal: %{
            title: "Finalized Deal",
            amount: "18500000",
            pipeline_column_id: won.id,
            notes: "Contract signed today"
          }
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/deals/#{deal}")

      assert html =~ "Deal updated successfully."
      assert html =~ "Finalized Deal"
      assert html =~ "Rp 18.500.000"
      assert html =~ "Won"
    end
  end
end
