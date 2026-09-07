defmodule Alur.NextActionsTest do
  use Alur.DataCase

  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.Activities
  alias Alur.DealsFixtures
  alias Alur.NextActions
  alias Alur.NextActions.NextAction
  alias Alur.NextActionsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    deal = DealsFixtures.deal_fixture(scope)
    %{user: user, scope: scope, deal: deal}
  end

  describe "next_actions context" do
    test "create_next_action/3 with date only schedules action and logs activity", %{
      scope: scope,
      deal: deal
    } do
      future_date = Date.utc_today() |> Date.add(3)

      assert {:ok, %NextAction{} = action} =
               NextActions.create_next_action(scope, deal.id, %{
                 what: "Send contract proposal",
                 due_date: future_date
               })

      assert action.what == "Send contract proposal"
      assert action.due_date == future_date
      assert action.due_time == nil
      assert action.done == false
      assert action.deal_id == deal.id
      assert action.user_id == scope.user.id

      # Activity stream must include the added action line
      activities = Activities.list_activities_for_deal(scope, deal.id)
      added_act = Enum.find(activities, &(&1.action_type == "next_action_added"))
      assert added_act != nil
      assert added_act.description == "Added next action: Send contract proposal"
    end

    test "create_next_action/3 with date and time schedules action and logs activity", %{
      scope: scope,
      deal: deal
    } do
      future_date = Date.utc_today() |> Date.add(1)
      time = ~T[14:30:00]

      assert {:ok, %NextAction{} = action} =
               NextActions.create_next_action(scope, deal.id, %{
                 what: "Zoom call with CTO",
                 due_date: future_date,
                 due_time: time
               })

      assert action.what == "Zoom call with CTO"
      assert action.due_date == future_date
      assert action.due_time == time
      assert action.done == false

      # Asia/Jakarta is UTC+7: 14:30 WIB is 07:30 UTC
      expected_due_at =
        DateTime.new!(future_date, time, "Etc/UTC") |> DateTime.add(-7 * 3600, :second)

      assert action.due_at == expected_due_at

      activities = Activities.list_activities_for_deal(scope, deal.id)
      added_act = Enum.find(activities, &(&1.action_type == "next_action_added"))
      assert added_act != nil
      assert added_act.description == "Added next action: Zoom call with CTO"
    end

    test "create_next_action/3 fails with invalid attributes", %{scope: scope, deal: deal} do
      assert {:error, changeset} = NextActions.create_next_action(scope, deal.id, %{what: ""})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).what
      assert "can't be blank" in errors_on(changeset).due_date
    end

    test "complete_next_action/2 marks action as done and logs activity", %{
      scope: scope,
      deal: deal
    } do
      action = NextActionsFixtures.next_action_fixture(scope, deal, %{what: "Prepare slide deck"})
      assert action.done == false

      assert {:ok, %NextAction{} = completed} = NextActions.complete_next_action(scope, action.id)
      assert completed.done == true
      assert completed.completed_at != nil

      activities = Activities.list_activities_for_deal(scope, deal.id)
      completed_act = Enum.find(activities, &(&1.action_type == "next_action_completed"))
      assert completed_act != nil
      assert completed_act.description == "Completed next action: Prepare slide deck"

      # Idempotent: completing again should not double-log
      assert {:ok, %NextAction{}} = NextActions.complete_next_action(scope, action.id)
      completed_acts = Enum.filter(activities, &(&1.action_type == "next_action_completed"))
      assert length(completed_acts) == 1
    end

    test "list_incomplete_actions/1 returns only open actions across deals ordered soonest due first",
         %{scope: scope, deal: deal} do
      deal2 = DealsFixtures.deal_fixture(scope)

      # Create 3 actions with different due dates
      past_date = Date.utc_today() |> Date.add(-1)
      today_date = Date.utc_today()
      future_date = Date.utc_today() |> Date.add(5)

      act_future =
        NextActionsFixtures.next_action_fixture(scope, deal, %{
          what: "Future task",
          due_date: future_date
        })

      act_past =
        NextActionsFixtures.next_action_fixture(scope, deal2, %{
          what: "Past task",
          due_date: past_date
        })

      act_today =
        NextActionsFixtures.next_action_fixture(scope, deal, %{
          what: "Today task",
          due_date: today_date
        })

      # Mark one done
      {:ok, _} = NextActions.complete_next_action(scope, act_future.id)

      open_actions = NextActions.list_incomplete_actions(scope)
      ids = Enum.map(open_actions, & &1.id)

      # Only past and today should be in open actions; past must come before today
      assert ids == [act_past.id, act_today.id]
      refute act_future.id in ids

      # Preloads deal
      assert hd(open_actions).deal.id == deal2.id
    end

    test "list_next_actions_for_deal/2 separates incomplete and completed", %{
      scope: scope,
      deal: deal
    } do
      act1 = NextActionsFixtures.next_action_fixture(scope, deal, %{what: "Task 1"})
      act2 = NextActionsFixtures.next_action_fixture(scope, deal, %{what: "Task 2"})

      {:ok, _} = NextActions.complete_next_action(scope, act2.id)

      incomplete = NextActions.list_incomplete_actions_for_deal(scope, deal.id)
      completed = NextActions.list_completed_actions_for_deal(scope, deal.id)

      assert length(incomplete) == 1
      assert hd(incomplete).id == act1.id

      assert length(completed) == 1
      assert hd(completed).id == act2.id
    end

    test "overdue?/2 correctly detects past vs future due dates", %{scope: scope, deal: deal} do
      past_action =
        NextActionsFixtures.next_action_fixture(scope, deal, %{
          what: "Overdue task",
          due_date: Date.utc_today() |> Date.add(-2)
        })

      future_action =
        NextActionsFixtures.next_action_fixture(scope, deal, %{
          what: "Future task",
          due_date: Date.utc_today() |> Date.add(2)
        })

      assert NextActions.overdue?(past_action) == true
      assert NextActions.overdue?(future_action) == false

      # Completed action is never overdue
      {:ok, completed_past} = NextActions.complete_next_action(scope, past_action.id)
      assert NextActions.overdue?(completed_past) == false
    end

    test "format_due/1 formats date and optional time correctly", %{scope: scope, deal: deal} do
      date = ~D[2026-09-10]
      time = ~T[14:00:00]

      action_with_time =
        NextActionsFixtures.next_action_fixture(scope, deal, %{
          what: "With time",
          due_date: date,
          due_time: time
        })

      action_date_only =
        NextActionsFixtures.next_action_fixture(scope, deal, %{
          what: "Date only",
          due_date: date,
          due_time: nil
        })

      assert NextActions.format_due(action_with_time) == "10 Sep 2026, 14:00"
      assert NextActions.format_due(action_date_only) == "10 Sep 2026"
    end
  end

  describe "multi-tenant isolation" do
    test "user cannot view or modify actions of another user's deal", %{
      scope: scope_a
    } do
      user_b = AccountsFixtures.user_fixture()
      scope_b = Scope.for_user(user_b)
      deal_b = DealsFixtures.deal_fixture(scope_b)

      action_b =
        NextActionsFixtures.next_action_fixture(scope_b, deal_b, %{
          what: "Secret deal B follow-up"
        })

      # User A cannot see user B's actions in open actions
      todos_a = NextActions.list_incomplete_actions(scope_a)
      refute Enum.any?(todos_a, &(&1.id == action_b.id))

      # User A cannot list actions for deal B
      assert NextActions.list_next_actions_for_deal(scope_a, deal_b.id) == []

      # User A cannot create action for deal B
      assert NextActions.create_next_action(scope_a, deal_b.id, %{
               what: "Unauthorized task",
               due_date: Date.utc_today()
             }) == {:error, :not_found}

      # User A cannot complete action of deal B
      assert NextActions.complete_next_action(scope_a, action_b.id) == {:error, :not_found}
    end
  end
end
