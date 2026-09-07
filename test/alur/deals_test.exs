defmodule Alur.DealsTest do
  use Alur.DataCase

  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.ContactsFixtures
  alias Alur.Deals
  alias Alur.Deals.Currency
  alias Alur.Deals.Deal
  alias Alur.DealsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    contact = ContactsFixtures.contact_fixture(scope)

    %{user: user, scope: scope, contact: contact}
  end

  describe "currency formatting" do
    test "formats various amounts in Indonesian Rupiah" do
      assert Currency.format_idr(0) == "Rp 0"
      assert Currency.format_idr(500) == "Rp 500"
      assert Currency.format_idr(10_000) == "Rp 10.000"
      assert Currency.format_idr(250_000) == "Rp 250.000"
      assert Currency.format_idr(15_000_000) == "Rp 15.000.000"
      assert Currency.format_idr(1_500_000_000) == "Rp 1.500.000.000"
      assert Currency.format_idr(-50_000) == "-Rp 50.000"
      assert Currency.format_idr(nil) == "Rp 0"
      assert Currency.format_idr("15000000") == "Rp 15.000.000"
    end
  end

  describe "pipeline columns" do
    test "lists the 5 default columns in order" do
      columns = Deals.list_pipeline_columns()
      assert length(columns) == 5
      assert Enum.map(columns, & &1.name) == ["Lead", "Meeting", "Proposal", "Won", "Lost"]
      assert Enum.map(columns, & &1.order) == [1, 2, 3, 4, 5]
    end

    test "default_pipeline_column returns Lead" do
      col = Deals.default_pipeline_column()
      assert col.name == "Lead"
      assert col.order == 1
    end

    test "get_pipeline_column! and get_pipeline_column_by_name" do
      lead = Deals.get_pipeline_column_by_name("Lead")
      assert lead.name == "Lead"
      assert Deals.get_pipeline_column!(lead.id) == lead
    end
  end

  describe "deals management" do
    test "create_deal/2 with valid attributes creates a deal", %{scope: scope, contact: contact} do
      attrs = %{
        title: "Enterprise License",
        amount: 15_000_000,
        notes: "Budget approved",
        contact_id: contact.id
      }

      assert {:ok, %Deal{} = deal} = Deals.create_deal(scope, attrs)
      assert deal.title == "Enterprise License"
      assert deal.amount == 15_000_000
      assert deal.notes == "Budget approved"
      assert deal.contact_id == contact.id
      assert deal.pipeline_column.name == "Lead"
      assert deal.contact.id == contact.id
    end

    test "create_deal/2 sanitizes string amounts with symbols and dots", %{
      scope: scope,
      contact: contact
    } do
      attrs = %{
        title: "SaaS Contract",
        amount: "Rp 25.000.000",
        contact_id: contact.id
      }

      assert {:ok, %Deal{} = deal} = Deals.create_deal(scope, attrs)
      assert deal.amount == 25_000_000
    end

    test "create_deal/2 validates required fields", %{scope: scope} do
      assert {:error, %Ecto.Changeset{} = changeset} = Deals.create_deal(scope, %{})
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).contact_id
    end

    test "create_deal/2 rejects negative amount", %{scope: scope, contact: contact} do
      attrs = %{title: "Invalid Deal", amount: -100, contact_id: contact.id}
      assert {:error, %Ecto.Changeset{} = changeset} = Deals.create_deal(scope, attrs)
      assert "must be greater than or equal to 0" in errors_on(changeset).amount
    end

    test "list_deals/2 and list_deals_for_contact/2", %{scope: scope, contact: contact} do
      deal1 = DealsFixtures.deal_fixture(scope, %{contact_id: contact.id, title: "Deal 1"})
      deal2 = DealsFixtures.deal_fixture(scope, %{contact_id: contact.id, title: "Deal 2"})

      other_contact = ContactsFixtures.contact_fixture(scope)
      deal3 = DealsFixtures.deal_fixture(scope, %{contact_id: other_contact.id, title: "Deal 3"})

      all_deals = Deals.list_deals(scope)
      deal_ids = Enum.map(all_deals, & &1.id)
      assert deal1.id in deal_ids
      assert deal2.id in deal_ids
      assert deal3.id in deal_ids

      contact_deals = Deals.list_deals_for_contact(scope, contact.id)
      contact_deal_ids = Enum.map(contact_deals, & &1.id)
      assert deal1.id in contact_deal_ids
      assert deal2.id in contact_deal_ids
      refute deal3.id in contact_deal_ids
    end

    test "get_deal!/2 and get_deal/2", %{scope: scope} do
      deal = DealsFixtures.deal_fixture(scope)
      assert Deals.get_deal!(scope, deal.id).id == deal.id
      assert {:ok, fetched} = Deals.get_deal(scope, deal.id)
      assert fetched.id == deal.id
      assert Deals.get_deal(scope, Ecto.UUID.generate()) == {:error, :not_found}
    end

    test "update_deal/3 updates fields", %{scope: scope} do
      deal = DealsFixtures.deal_fixture(scope, %{amount: 10_000_000})

      assert {:ok, updated} =
               Deals.update_deal(scope, deal, %{
                 title: "Updated Title",
                 amount: "20.000.000",
                 notes: "New notes"
               })

      assert updated.title == "Updated Title"
      assert updated.amount == 20_000_000
      assert updated.notes == "New notes"
    end

    test "change_deal_stage/3 and move_deal/3 changes the column", %{scope: scope} do
      deal = DealsFixtures.deal_fixture(scope)
      proposal = Deals.get_pipeline_column_by_name("Proposal")

      assert {:ok, updated} = Deals.change_deal_stage(scope, deal, proposal.id)
      assert updated.pipeline_column_id == proposal.id
      assert updated.pipeline_column.name == "Proposal"

      meeting = Deals.get_pipeline_column_by_name("Meeting")
      assert {:ok, moved} = Deals.move_deal(scope, updated, meeting.id)
      assert moved.pipeline_column_id == meeting.id
      assert moved.pipeline_column.name == "Meeting"

      # Moving by column name
      assert {:ok, moved_by_name} = Deals.move_deal(scope, moved, "Won")
      assert moved_by_name.pipeline_column.name == "Won"

      # Moving by deal_id
      assert {:ok, moved_by_id} = Deals.move_deal(scope, deal.id, "Lost")
      assert moved_by_id.pipeline_column.name == "Lost"

      # Unknown column returns error
      assert Deals.move_deal(scope, deal.id, "NonExistentColumn") == {:error, :invalid_column}
    end

    test "get_pipeline_board/1 returns 5 columns in order with deals and totals", %{scope: scope} do
      lead_col = Deals.get_pipeline_column_by_name("Lead")
      meeting_col = Deals.get_pipeline_column_by_name("Meeting")

      deal1 =
        DealsFixtures.deal_fixture(scope, %{
          title: "Deal 1",
          amount: 10_000_000,
          pipeline_column_id: lead_col.id
        })

      deal2 =
        DealsFixtures.deal_fixture(scope, %{
          title: "Deal 2",
          amount: 5_000_000,
          pipeline_column_id: lead_col.id
        })

      deal3 =
        DealsFixtures.deal_fixture(scope, %{
          title: "Deal 3",
          amount: 25_000_000,
          pipeline_column_id: meeting_col.id
        })

      board = Deals.get_pipeline_board(scope)
      assert length(board) == 5

      column_names = Enum.map(board, & &1.column.name)
      assert column_names == ["Lead", "Meeting", "Proposal", "Won", "Lost"]

      lead_stage = Enum.find(board, &(&1.column.name == "Lead"))
      assert lead_stage.count == 2
      assert lead_stage.total_amount == 15_000_000
      lead_deal_ids = Enum.map(lead_stage.deals, & &1.id)
      assert deal1.id in lead_deal_ids
      assert deal2.id in lead_deal_ids

      meeting_stage = Enum.find(board, &(&1.column.name == "Meeting"))
      assert meeting_stage.count == 1
      assert meeting_stage.total_amount == 25_000_000
      assert hd(meeting_stage.deals).id == deal3.id

      proposal_stage = Enum.find(board, &(&1.column.name == "Proposal"))
      assert proposal_stage.count == 0
      assert proposal_stage.total_amount == 0
      assert proposal_stage.deals == []
    end

    test "delete_deal/2 removes the deal", %{scope: scope} do
      deal = DealsFixtures.deal_fixture(scope)
      assert {:ok, %Deal{}} = Deals.delete_deal(scope, deal)
      assert Deals.get_deal(scope, deal.id) == {:error, :not_found}
    end
  end

  describe "multi-tenant isolation" do
    test "cannot view, update, or delete another user's deal", %{scope: scope_a} do
      user_b = AccountsFixtures.user_fixture()
      scope_b = Scope.for_user(user_b)
      deal_b = DealsFixtures.deal_fixture(scope_b, %{title: "User B Secret Deal"})

      # User A cannot see it in list
      refute deal_b.id in Enum.map(Deals.list_deals(scope_a), & &1.id)

      # User A cannot fetch it
      assert Deals.get_deal(scope_a, deal_b.id) == {:error, :not_found}

      assert_raise Ecto.NoResultsError, fn ->
        Deals.get_deal!(scope_a, deal_b.id)
      end

      # User A cannot update it
      assert_raise FunctionClauseError, fn ->
        Deals.update_deal(scope_a, deal_b, %{title: "Hijacked"})
      end

      # User A cannot delete it
      assert_raise FunctionClauseError, fn ->
        Deals.delete_deal(scope_a, deal_b)
      end
    end

    test "cannot attach a deal to another user's contact", %{scope: scope_a} do
      user_b = AccountsFixtures.user_fixture()
      scope_b = Scope.for_user(user_b)
      contact_b = ContactsFixtures.contact_fixture(scope_b)

      assert {:error, changeset} =
               Deals.create_deal(scope_a, %{
                 title: "Malicious Deal",
                 amount: 10_000_000,
                 contact_id: contact_b.id
               })

      assert "is invalid" in errors_on(changeset).contact_id
    end

    test "cannot move another user's deal", %{scope: scope_a} do
      user_b = AccountsFixtures.user_fixture()
      scope_b = Scope.for_user(user_b)
      deal_b = DealsFixtures.deal_fixture(scope_b, %{title: "User B Deal"})
      proposal = Deals.get_pipeline_column_by_name("Proposal")

      assert Deals.move_deal(scope_a, deal_b.id, proposal.id) == {:error, :not_found}
      assert Deals.move_deal(scope_a, deal_b, proposal.id) == {:error, :unauthorized}
    end

    test "get_pipeline_board does not leak another user's deals", %{scope: scope_a} do
      user_b = AccountsFixtures.user_fixture()
      scope_b = Scope.for_user(user_b)

      deal_b =
        DealsFixtures.deal_fixture(scope_b, %{title: "User B Private Deal", amount: 50_000_000})

      board_a = Deals.get_pipeline_board(scope_a)
      all_deal_ids_a = board_a |> Enum.flat_map(& &1.deals) |> Enum.map(& &1.id)
      refute deal_b.id in all_deal_ids_a

      total_a = board_a |> Enum.map(& &1.total_amount) |> Enum.sum()
      assert total_a == 0
    end
  end
end
