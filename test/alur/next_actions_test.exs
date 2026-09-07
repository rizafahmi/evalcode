defmodule Alur.NextActionsTest do
  use Alur.DataCase, async: false

  import Ecto.Query

  alias Alur.Accounts
  alias Alur.Activities
  alias Alur.Contacts
  alias Alur.Deals
  alias Alur.NextActions
  alias Alur.NextActions.NextAction
  alias Alur.Repo

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

  defp contact!(account) do
    {:ok, contact} = Contacts.create_contact(account, %{name: "Sari Wijaya"})
    contact
  end

  defp column!(name) do
    Enum.find(Deals.list_pipeline_columns(), &(&1.name == name))
  end

  defp deal!(account, contact, overrides \\ %{}) do
    {:ok, deal} =
      Deals.create_deal(
        account,
        contact,
        Enum.into(overrides, %{
          title: "Website redesign",
          amount: 15_000_000,
          pipeline_column_id: column!("Lead").id
        })
      )

    deal
  end

  defp follow_up!(deal, overrides) do
    {:ok, next_action} = NextActions.create_for_deal(deal, overrides)
    next_action
  end

  describe "create_for_deal/2" do
    test "schedules a follow-up on the deal and writes its 'Follow-up added' log line" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      assert {:ok, %NextAction{} = next_action} =
               NextActions.create_for_deal(deal, %{
                 what: "Call Sari about the proposal",
                 due_date: ~D[2026-09-30],
                 due_time: ~T[14:00:00]
               })

      assert next_action.deal_id == deal.id
      assert next_action.what == "Call Sari about the proposal"
      assert next_action.due_date == ~D[2026-09-30]
      assert next_action.due_time == ~T[14:00:00]
      assert next_action.done == false

      # The deal's log gained exactly one line, above the created line.
      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == [
               "Follow-up added: Call Sari about the proposal",
               "Deal created"
             ]
    end

    test "lets the time stay blank (date-only follow-ups are due by end of day)" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      assert {:ok, %NextAction{due_time: nil}} =
               NextActions.create_for_deal(deal, %{
                 what: "Send the contract",
                 due_date: ~D[2026-09-30]
               })
    end

    test "requires a what and a due date" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      assert {:error, changeset} = NextActions.create_for_deal(deal, %{})
      assert "can't be blank" in errors_on(changeset).what
      assert "can't be blank" in errors_on(changeset).due_date

      # No follow-up was written, and the deal's log keeps exactly its opening
      # line.
      assert Repo.all(from na in NextAction, where: na.deal_id == ^deal.id) == []
      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == ["Deal created"]
    end

    test "rejects an overlong what" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      assert {:error, changeset} =
               NextActions.create_for_deal(deal, %{
                 what: String.duplicate("x", 201),
                 due_date: ~D[2026-09-30]
               })

      assert errors_on(changeset).what != []
    end

    test "ignores any deal_id smuggled through the attrs" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)
      other = deal!(account, contact)

      assert {:ok, %NextAction{deal_id: deal_id}} =
               NextActions.create_for_deal(deal, %{
                 what: "Stays on the right deal",
                 due_date: ~D[2026-09-30],
                 deal_id: other.id
               })

      assert deal_id == deal.id
    end
  end

  describe "list_for_deal/1" do
    test "returns only this deal's follow-ups, open first, each soonest due first" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)
      other_deal = deal!(account, contact)

      # Same deal, mixed dates and times.
      follow_up!(deal, %{what: "Late", due_date: ~D[2026-09-25], due_time: ~T[09:00:00]})
      follow_up!(deal, %{what: "No time later", due_date: ~D[2026-09-15]})
      follow_up!(deal, %{what: "Timed earlier", due_date: ~D[2026-09-15], due_time: ~T[08:00:00]})
      follow_up!(deal, %{what: "Soonest", due_date: ~D[2026-09-10]})

      # A follow-up on another deal never leaks in.
      follow_up!(other_deal, %{what: "Other deal's task", due_date: ~D[2026-09-01]})

      # Open rows: soonest due date first; within the same day, a timed row
      # sorts before the date-only one (due by end of that day).
      assert Enum.map(NextActions.list_for_deal(deal), & &1.what) == [
               "Soonest",
               "Timed earlier",
               "No time later",
               "Late"
             ]
    end

    test "completed follow-ups stay visible after the open ones" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)

      follow_up!(deal, %{what: "Later task", due_date: ~D[2026-09-25]})
      done = follow_up!(deal, %{what: "Done task", due_date: ~D[2026-09-10]})
      {:ok, %NextAction{done: true}} = NextActions.complete(done)

      assert Enum.map(NextActions.list_for_deal(deal), &{&1.what, &1.done}) == [
               {"Later task", false},
               {"Done task", true}
             ]
    end
  end

  describe "list_open/1" do
    test "returns only the account's incomplete follow-ups, soonest first, with deals preloaded" do
      account = account!()
      other = account!()
      contact = contact!(account)
      other_contact = contact!(other)

      deal_a = deal!(account, contact)
      deal_b = deal!(account, contact)

      {:ok, _older} =
        NextActions.create_for_deal(deal_a, %{
          what: "Older",
          due_date: ~D[2026-09-10],
          due_time: ~T[10:00:00]
        })

      {:ok, _newer} =
        NextActions.create_for_deal(deal_b, %{
          what: "Newer",
          due_date: ~D[2026-09-20]
        })

      {:ok, _completed} =
        deal_a
        |> follow_up!(%{what: "Done already", due_date: ~D[2026-09-01]})
        |> then(&NextActions.complete/1)

      # The other account's follow-up never shows up here.
      {:ok, _foreign} =
        NextActions.create_for_deal(deal!(other, other_contact), %{
          what: "Not yours",
          due_date: ~D[2026-09-01]
        })

      rows = NextActions.list_open(account)
      assert Enum.map(rows, & &1.what) == ["Older", "Newer"]

      # Each open row carries its deal so the To-dos page can link through.
      assert [%NextAction{deal: %{title: "Website redesign"}} | _] = rows
      assert Enum.all?(rows, &(&1.deal.account_id == account.id))
    end
  end

  describe "complete/1" do
    test "marks a follow-up done and writes a 'Follow-up completed' log line on its deal" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)
      next_action = follow_up!(deal, %{what: "Close the loop", due_date: ~D[2026-09-30]})

      assert {:ok, %NextAction{done: true} = completed} = NextActions.complete(next_action)
      assert completed.id == next_action.id

      assert Enum.map(Activities.list_for_deal(deal), & &1.description) == [
               "Follow-up completed: Close the loop",
               "Follow-up added: Close the loop",
               "Deal created"
             ]
    end

    test "completing an already-done follow-up is a no-op that writes no second line" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)
      next_action = follow_up!(deal, %{what: "One line only", due_date: ~D[2026-09-30]})

      assert {:ok, _completed} = NextActions.complete(next_action)
      assert {:ok, _completed} = NextActions.complete(next_action)

      assert Enum.filter(
               Activities.list_for_deal(deal),
               &String.starts_with?(&1.description, "Follow-up completed")
             )
             |> length() == 1
    end

    test "a completed follow-up leaves the open list but stays on the deal" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)
      next_action = follow_up!(deal, %{what: "Send the invoice", due_date: ~D[2026-09-30]})

      assert [%NextAction{}] = NextActions.list_open(account)
      {:ok, _completed} = NextActions.complete(next_action)

      assert NextActions.list_open(account) == []

      assert Enum.map(NextActions.list_for_deal(deal), &{&1.what, &1.done}) == [
               {"Send the invoice", true}
             ]
    end
  end

  describe "overdue?/2" do
    # ~U[2025-09-12 00:00:00Z] is 07:00 WIB on 12 Sep 2025.
    @jakarta_morning ~U[2025-09-12 00:00:00Z]

    test "a date-only follow-up is overdue once its day is behind the Jakarta day" do
      assert NextActions.overdue?(
               %NextAction{due_date: ~D[2025-09-11], due_time: nil},
               @jakarta_morning
             )

      assert NextActions.overdue?(
               %NextAction{due_date: ~D[2025-09-12], due_time: nil},
               @jakarta_morning
             ) == false

      assert NextActions.overdue?(
               %NextAction{due_date: ~D[2025-09-13], due_time: nil},
               @jakarta_morning
             ) == false
    end

    test "a timed follow-up is overdue once its combined moment is past in Jakarta" do
      # 06:00 WIB has passed by 07:00 WIB…
      assert NextActions.overdue?(
               %NextAction{due_date: ~D[2025-09-12], due_time: ~T[06:00:00]},
               @jakarta_morning
             )

      # …while 08:00 WIB is still ahead.
      assert NextActions.overdue?(
               %NextAction{due_date: ~D[2025-09-12], due_time: ~T[08:00:00]},
               @jakarta_morning
             ) == false
    end

    test "compares against the Asia/Jakarta day, not the UTC day" do
      # 17:30 UTC on 11 Sep is already 12 Sep, 00:30 WIB — so a follow-up due
      # on 11 Sep (Jakarta) is overdue even though the UTC date is 11 Sep.
      assert NextActions.overdue?(
               %NextAction{due_date: ~D[2025-09-11], due_time: nil},
               ~U[2025-09-11 17:30:00Z]
             )
    end

    test "completed follow-ups are never overdue" do
      assert NextActions.overdue?(
               %NextAction{done: true, due_date: ~D[2020-01-01], due_time: nil},
               @jakarta_morning
             ) == false
    end
  end

  describe "format_due/1" do
    test "shows the day, plus the time in WIB when one was chosen" do
      assert NextActions.format_due(%NextAction{due_date: ~D[2025-09-12], due_time: nil}) ==
               "12 Sep 2025"

      assert NextActions.format_due(%NextAction{due_date: ~D[2025-09-12], due_time: ~T[14:00:00]}) ==
               "12 Sep 2025, 14:00 WIB"
    end
  end

  describe "deleting the deal" do
    test "removes its follow-ups, so none survive orphaned" do
      account = account!()
      contact = contact!(account)
      deal = deal!(account, contact)
      follow_up!(deal, %{what: "Dies with the deal", due_date: ~D[2026-09-30]})

      assert {:ok, _deal} = Deals.delete_deal(deal)
      assert Repo.all(from na in NextAction, where: na.deal_id == ^deal.id) == []
    end
  end
end
