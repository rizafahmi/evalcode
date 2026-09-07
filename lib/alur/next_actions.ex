defmodule Alur.NextActions do
  @moduledoc """
  The NextActions context manages the follow-ups scheduled on deals.

  A follow-up belongs to one deal of the signed-in account, so every read here
  is anchored to a deal already fetched account-scoped (`Alur.Deals.get_deal/2`)
  or joins through the account's deals, keeping one account's follow-ups out of
  another account's to-do list.

  Adding a follow-up and completing one both write an immutable line on the
  deal's activity log through `Alur.Activities.log/2` — the deal page therefore
  shows `Follow-up added: …` and `Follow-up completed: …` lines next to the
  follow-ups themselves.
  """

  import Ecto.Query, warn: false

  alias Alur.Accounts.Account
  alias Alur.Activities
  alias Alur.Deals.Deal
  alias Alur.NextActions.NextAction
  alias Alur.Repo

  # Jakarta observes a fixed UTC+7 offset all year, so "now in Asia/Jakarta"
  # is plain arithmetic on the UTC clock (see `overdue?/2`).
  @jakarta_offset_hours 7

  @doc """
  Returns every follow-up on `deal`, open ones first and then completed ones,
  each group soonest due first (an item with a time sorts before a same-day
  item that has no time — a date-only follow-up is due by the end of that day).
  """
  def list_for_deal(%Deal{id: deal_id}) do
    Repo.all(
      from(na in NextAction,
        where: na.deal_id == ^deal_id,
        order_by: [asc: na.done, asc: na.due_date, asc_nulls_last: na.due_time]
      )
    )
  end

  @doc """
  Returns every *incomplete* follow-up across the deals of `account`, soonest
  due first, with each row's deal preloaded.

  This is the account-scoped list behind the To-dos page: another account's
  follow-ups (through another account's deals) never appear here.
  """
  def list_open(%Account{id: account_id}) do
    Repo.all(
      from(na in NextAction,
        join: d in assoc(na, :deal),
        where: na.done == false and d.account_id == ^account_id,
        order_by: [asc: na.due_date, asc_nulls_last: na.due_time],
        preload: [:deal]
      )
    )
  end

  @doc """
  Schedules a new follow-up on `deal`.

  The follow-up and its `Follow-up added: …` activity-log line are written in
  one transaction, so a follow-up never exists without its log line.

  Returns `{:ok, next_action}` or `{:error, changeset}`.
  """
  def create_for_deal(%Deal{} = deal, attrs \\ %{}) do
    Repo.transaction(fn ->
      with {:ok, next_action} <-
             %NextAction{deal_id: deal.id}
             |> NextAction.changeset(attrs)
             |> Repo.insert(),
           {:ok, _activity} <- Activities.log(deal, "Follow-up added: " <> next_action.what) do
        next_action
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Marks a follow-up as done and writes the matching `Follow-up completed: …`
  activity-log line on its deal.

  Returns `{:ok, next_action}`. Completing a follow-up that is already done in
  the database is a no-op that never writes a second log line, even when the
  struct handed in is stale.
  """
  def complete(%NextAction{} = next_action) do
    case Repo.get(NextAction, next_action.id) do
      nil ->
        {:error, :not_found}

      %NextAction{done: true} = current ->
        {:ok, current}

      %NextAction{} = current ->
        do_complete(current)
    end
  end

  defp do_complete(%NextAction{} = next_action) do
    deal = %Deal{id: next_action.deal_id}

    Repo.transaction(fn ->
      with {:ok, updated} <-
             next_action
             |> NextAction.changeset(%{done: true})
             |> Repo.update(),
           {:ok, _activity} <-
             Activities.log(deal, "Follow-up completed: " <> next_action.what) do
        updated
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Whether an open follow-up is overdue compared to the current moment in
  Asia/Jakarta (defaulting to right now).

  A date-only follow-up is due by the end of its day, so it only becomes
  overdue once the Jakarta date has moved past it; a follow-up with a time is
  overdue once the combined date and time are in the past. Completed
  follow-ups are never overdue.

      iex> Alur.NextActions.overdue?(%Alur.NextActions.NextAction{
      ...>   due_date: ~D[2025-09-11], due_time: nil
      ...> }, ~U[2025-09-12 00:00:00Z])
      true

  Jakarta has a fixed UTC+7 offset with no daylight saving, so the comparison
  is plain arithmetic on the UTC clock — no time-zone database is needed.
  """
  def overdue?(next_action, now \\ DateTime.utc_now())

  def overdue?(%NextAction{done: true}, _now), do: false

  def overdue?(%NextAction{due_date: due_date, due_time: due_time}, now) do
    {today, now_time} = jakarta_now(now)

    case Date.compare(due_date, today) do
      :lt -> true
      :gt -> false
      :eq -> past_time?(due_time, now_time)
    end
  end

  @doc """
  Formats when a follow-up is due the way the app shows it: the day always,
  and the time in Western Indonesia Time when one was chosen.

      iex> Alur.NextActions.format_due(%Alur.NextActions.NextAction{
      ...>   due_date: ~D[2025-09-12], due_time: ~T[14:00:00]
      ...> })
      "12 Sep 2025, 14:00 WIB"
  """
  def format_due(%NextAction{due_date: due_date, due_time: nil}) do
    Calendar.strftime(due_date, "%d %b %Y")
  end

  def format_due(%NextAction{due_date: due_date, due_time: due_time}) do
    Calendar.strftime(due_date, "%d %b %Y") <>
      ", " <> Calendar.strftime(due_time, "%H:%M") <> " WIB"
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for a follow-up form.
  """
  def change_next_action(%NextAction{} = next_action, attrs \\ %{}) do
    NextAction.changeset(next_action, attrs)
  end

  # A date-only item is due by the end of its Jakarta day, so a nil time can
  # never be past while the day is still today.
  defp past_time?(nil, _now_time), do: false

  defp past_time?(due_time, now_time), do: Time.compare(due_time, now_time) == :lt

  defp jakarta_now(now) do
    shifted = DateTime.add(now, @jakarta_offset_hours * 60 * 60)
    {DateTime.to_date(shifted), DateTime.to_time(shifted)}
  end
end
