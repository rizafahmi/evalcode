defmodule Alur.ActivitiesTest do
  use Alur.DataCase

  alias Alur.Accounts.Scope
  alias Alur.AccountsFixtures
  alias Alur.Activities
  alias Alur.Activities.Activity
  alias Alur.Deals
  alias Alur.DealsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)
    %{user: user, scope: scope}
  end

  describe "activities context" do
    test "log_deal_created/2 records a created activity", %{scope: scope} do
      deal = DealsFixtures.deal_fixture(scope)

      activities = Activities.list_activities_for_deal(scope, deal.id)
      refute Enum.empty?(activities)

      created_activity = Enum.find(activities, &(&1.action_type == "created"))
      assert created_activity != nil
      assert created_activity.description == "Deal created"
      assert created_activity.deal_id == deal.id
      assert created_activity.user_id == scope.user.id
      assert created_activity.inserted_at != nil
    end

    test "log_deal_moved/4 records a moved activity", %{scope: scope} do
      deal = DealsFixtures.deal_fixture(scope)
      lead_col = Deals.get_pipeline_column_by_name("Lead")
      meeting_col = Deals.get_pipeline_column_by_name("Meeting")

      assert {:ok, %Activity{} = activity} =
               Activities.log_deal_moved(scope, deal, lead_col, meeting_col)

      assert activity.description == "Moved to Meeting"
      assert activity.action_type == "moved"
      from_name = activity.metadata["from_column_name"] || activity.metadata[:from_column_name]
      to_name = activity.metadata["to_column_name"] || activity.metadata[:to_column_name]
      assert from_name == "Lead"
      assert to_name == "Meeting"
    end

    test "log_note/3 records a manual free-text note", %{scope: scope} do
      deal = DealsFixtures.deal_fixture(scope)

      assert {:ok, %Activity{} = activity} =
               Activities.log_note(
                 scope,
                 deal.id,
                 "Spoke with client CFO regarding Q4 budget approval."
               )

      assert activity.description == "Spoke with client CFO regarding Q4 budget approval."
      assert activity.action_type == "note"
      assert activity.deal_id == deal.id
      assert activity.user_id == scope.user.id
    end

    test "list_activities_for_deal/2 returns activities ordered newest-first", %{scope: scope} do
      deal = DealsFixtures.deal_fixture(scope)

      {:ok, _} = Activities.log_note(scope, deal.id, "First note recorded")
      {:ok, _} = Activities.log_note(scope, deal.id, "Second note recorded")

      activities = Activities.list_activities_for_deal(scope, deal.id)
      descriptions = Enum.map(activities, & &1.description)

      # Second note must appear before first note
      assert hd(descriptions) == "Second note recorded"

      assert Enum.find_index(descriptions, &(&1 == "Second note recorded")) <
               Enum.find_index(descriptions, &(&1 == "First note recorded"))
    end

    test "milestone 6 hook points: log_next_action_added and log_next_action_completed", %{
      scope: scope
    } do
      deal = DealsFixtures.deal_fixture(scope)

      assert {:ok, %Activity{} = act_1} =
               Activities.log_next_action_added(scope, deal.id, "Send revised pricing schedule")

      assert act_1.description == "Added next action: Send revised pricing schedule"
      assert act_1.action_type == "next_action_added"

      assert {:ok, %Activity{} = act_2} =
               Activities.log_next_action_completed(
                 scope,
                 deal.id,
                 "Send revised pricing schedule"
               )

      assert act_2.description == "Completed next action: Send revised pricing schedule"
      assert act_2.action_type == "next_action_completed"
    end

    test "format_activity_time formats timestamp into human-readable Indonesian time", %{} do
      dt = ~U[2026-09-07 08:30:00Z]
      formatted = Activities.format_activity_time(dt)
      # 08:30 UTC + 7 hours = 15:30 WIB
      assert formatted =~ "07 Sep 2026"
      assert formatted =~ "15:30"
    end
  end

  describe "multi-tenant isolation" do
    test "user cannot list or log activities on another user's deal", %{scope: scope_a} do
      user_b = AccountsFixtures.user_fixture()
      scope_b = Scope.for_user(user_b)
      deal_b = DealsFixtures.deal_fixture(scope_b)

      # User A cannot list activities of deal B
      assert Activities.list_activities_for_deal(scope_a, deal_b.id) == []

      # User A cannot log a note on deal B
      assert Activities.log_note(scope_a, deal_b.id, "Unauthorized note") == {:error, :not_found}
    end
  end
end
