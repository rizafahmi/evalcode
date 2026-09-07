defmodule Alur.NextActions do
  @moduledoc """
  The NextActions context handles follow-up actions attached to deals.
  """

  import Ecto.Query, warn: false
  alias Alur.Accounts.Scope
  alias Alur.Activities
  alias Alur.Deals.Deal
  alias Alur.NextActions.NextAction
  alias Alur.Repo

  @doc """
  Lists all next actions for a given deal belonging to the scoped user.
  Sorted with incomplete actions first (soonest due first), followed by completed actions.
  """
  def list_next_actions_for_deal(%Scope{} = scope, deal_or_id) do
    deal_id = extract_id(deal_or_id)

    Repo.all(
      from n in NextAction,
        where: n.user_id == ^scope.user.id and n.deal_id == ^deal_id,
        order_by: [asc: n.done, asc: n.due_at, asc: n.inserted_at]
    )
  end

  @doc """
  Lists incomplete next actions for a deal belonging to the scoped user,
  sorted soonest due first.
  """
  def list_incomplete_actions_for_deal(%Scope{} = scope, deal_or_id) do
    deal_id = extract_id(deal_or_id)

    Repo.all(
      from n in NextAction,
        where: n.user_id == ^scope.user.id and n.deal_id == ^deal_id and n.done == false,
        order_by: [asc: n.due_at, asc: n.inserted_at]
    )
  end

  @doc """
  Lists completed next actions for a deal belonging to the scoped user,
  sorted newest completed first.
  """
  def list_completed_actions_for_deal(%Scope{} = scope, deal_or_id) do
    deal_id = extract_id(deal_or_id)

    Repo.all(
      from n in NextAction,
        where: n.user_id == ^scope.user.id and n.deal_id == ^deal_id and n.done == true,
        order_by: [desc: n.completed_at, desc: n.inserted_at]
    )
  end

  @doc """
  Lists all incomplete next actions across all deals belonging to the scoped user,
  sorted soonest due first. Preloads the associated deal and contact.
  """
  def list_incomplete_actions(%Scope{} = scope) do
    Repo.all(
      from n in NextAction,
        where: n.user_id == ^scope.user.id and n.done == false,
        order_by: [asc: n.due_at, asc: n.inserted_at],
        preload: [deal: :contact]
    )
  end

  @doc """
  Gets a single next action by ID, ensuring it belongs to the scoped user.
  Raises Ecto.NoResultsError if not found.
  """
  def get_next_action!(%Scope{} = scope, id) do
    Repo.one!(
      from n in NextAction,
        where: n.id == ^id and n.user_id == ^scope.user.id,
        preload: [:deal]
    )
  end

  @doc """
  Creates a next action for a deal belonging to the scoped user and automatically
  logs an activity line ("Added next action: <what>") on the deal.
  """
  def create_next_action(%Scope{} = scope, deal_or_id, attrs) do
    case find_scoped_deal(scope, deal_or_id) do
      nil ->
        {:error, :not_found}

      deal ->
        Repo.transaction(fn ->
          insert_and_log_action(scope, deal, attrs)
        end)
    end
  end

  defp find_scoped_deal(%Scope{} = scope, deal_or_id) do
    deal_id = extract_id(deal_or_id)
    Repo.one(from d in Deal, where: d.id == ^deal_id and d.user_id == ^scope.user.id)
  end

  defp insert_and_log_action(%Scope{} = scope, %Deal{} = deal, attrs) do
    changeset =
      %NextAction{user_id: scope.user.id, deal_id: deal.id}
      |> NextAction.changeset(attrs)

    with {:ok, next_action} <- Repo.insert(changeset),
         {:ok, _activity} <- Activities.log_next_action_added(scope, deal.id, next_action.what) do
      next_action
    else
      {:error, failure_changeset} ->
        Repo.rollback(failure_changeset)
    end
  end

  @doc """
  Marks a next action as completed, setting `done: true` and `completed_at`,
  and automatically logs an activity line ("Completed next action: <what>") on the deal.
  Idempotent: if already completed, returns `{:ok, next_action}` without logging duplicate activity.
  """
  def complete_next_action(%Scope{} = scope, next_action_or_id) do
    case find_scoped_action(scope, next_action_or_id) do
      nil ->
        {:error, :not_found}

      %NextAction{done: true} = action ->
        {:ok, action}

      %NextAction{} = action ->
        Repo.transaction(fn ->
          update_and_log_completion(scope, action)
        end)
    end
  end

  defp find_scoped_action(%Scope{} = scope, %NextAction{id: id}), do: get_action_by_id(scope, id)

  defp find_scoped_action(%Scope{} = scope, id) when is_binary(id),
    do: get_action_by_id(scope, id)

  defp find_scoped_action(_scope, _), do: nil

  defp get_action_by_id(%Scope{} = scope, id) do
    Repo.one(
      from n in NextAction, where: n.id == ^id and n.user_id == ^scope.user.id, preload: [:deal]
    )
  end

  defp update_and_log_completion(%Scope{} = scope, %NextAction{} = next_action) do
    changeset = NextAction.complete_changeset(next_action)

    with {:ok, updated} <- Repo.update(changeset),
         {:ok, _activity} <-
           Activities.log_next_action_completed(scope, updated.deal_id, updated.what) do
      updated
    else
      {:error, failure_changeset} ->
        Repo.rollback(failure_changeset)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking next action changes.
  """
  def change_next_action(%NextAction{} = next_action, attrs \\ %{}) do
    NextAction.changeset(next_action, attrs)
  end

  @doc """
  Checks if a next action is overdue compared to current time in Asia/Jakarta.
  Completed actions are never overdue.
  """
  def overdue?(%NextAction{done: true}, _current_time), do: false

  def overdue?(%NextAction{due_at: %DateTime{} = due_at}, current_time) do
    compare_overdue(due_at, current_time)
  end

  def overdue?(%NextAction{due_date: %Date{} = due_date, due_time: due_time}, current_time) do
    due_at = NextAction.compute_due_at(due_date, due_time)
    compare_overdue(due_at, current_time)
  end

  def overdue?(_, _), do: false

  @doc """
  Convenience overload for `overdue?/2` using current system time.
  """
  def overdue?(%NextAction{} = next_action), do: overdue?(next_action, nil)

  defp compare_overdue(due_at, nil) do
    DateTime.compare(DateTime.utc_now(), due_at) == :gt
  end

  defp compare_overdue(due_at, %DateTime{} = now) do
    now_utc =
      if now.time_zone == "Etc/UTC" do
        now
      else
        DateTime.add(now, -now.utc_offset - now.std_offset, :second)
      end

    DateTime.compare(now_utc, due_at) == :gt
  end

  defp compare_overdue(due_at, %Date{} = date) do
    # Comparing against a date means checking if the date's end of day in Jakarta has passed
    jakarta_end = DateTime.new!(date, ~T[23:59:59], "Etc/UTC") |> DateTime.add(-7 * 3600, :second)
    DateTime.compare(jakarta_end, due_at) == :gt
  end

  @doc """
  Formats a next action's due date and optional time into a human-readable string.
  E.g. "10 Sep 2026, 14:00" or "10 Sep 2026".
  """
  def format_due(%NextAction{due_date: %Date{} = due_date, due_time: %Time{} = due_time}) do
    date_str = Calendar.strftime(due_date, "%d %b %Y")
    time_str = Calendar.strftime(due_time, "%H:%M")
    "#{date_str}, #{time_str}"
  end

  def format_due(%NextAction{due_date: %Date{} = due_date, due_time: nil}) do
    Calendar.strftime(due_date, "%d %b %Y")
  end

  def format_due(_), do: ""

  defp extract_id(%{id: id}), do: id
  defp extract_id(id) when is_binary(id), do: id
  defp extract_id(_), do: nil
end
