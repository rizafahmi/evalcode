defmodule Alur.Activities do
  @moduledoc """
  The Activities context manages the immutable, timestamped log lines a deal
  keeps.

  A line has a short description (for example `Deal created`,
  `Moved from Lead to Meeting`, or a manual note) and is stamped when it is
  written; lines are never edited or deleted through the app. The deal pages
  render them newest-first.

  Writing happens through the deal-shaped entry points:

    * `Alur.Deals.create_deal/3` writes the `Deal created` line.
    * `Alur.Deals.move_deal/3` (and any `update_deal/2` that changes the
      pipeline column) writes the `Moved from … to …` line.
    * milestone 6 (next actions) hooks follow-up add/complete lines here, and
      manual notes are logged through `log/2`.

  Because lines belong to a deal, and deals are always fetched account-scoped
  by `Alur.Deals`, the log can never leak across accounts.
  """

  import Ecto.Query, warn: false

  alias Alur.Activities.Activity
  alias Alur.Deals.Deal
  alias Alur.Repo

  @jakarta_offset_hours 7

  @doc """
  Returns every log line for `deal`, newest first.
  """
  def list_for_deal(%Deal{id: deal_id}) do
    Repo.all(
      from(a in Activity,
        where: a.deal_id == ^deal_id,
        order_by: [desc: a.inserted_at]
      )
    )
  end

  @doc """
  Writes one immutable log line for `deal` with the given short description.

  Returns `{:ok, activity}` or `{:error, changeset}` when the description is
  blank or too long. The caller is responsible for building the description;
  the line is stamped automatically.
  """
  def log(%Deal{id: deal_id}, description) do
    %Activity{deal_id: deal_id}
    |> Activity.changeset(%{description: description})
    |> Repo.insert()
  end

  @doc """
  Formats an activity's timestamp the way the app shows log dates everywhere:
  the day and time in Western Indonesia Time (Asia/Jakarta, UTC+7 all year).

      iex> Alur.Activities.format_when(~U[2025-01-12 14:05:00Z])
      "12 Jan 2025, 21:05 WIB"

  Jakarta has observed a fixed UTC+7 offset for decades, so the shift is plain
  arithmetic on the UTC stamp — no time-zone database is needed to display it.
  """
  def format_when(%DateTime{} = datetime) do
    datetime
    |> DateTime.add(@jakarta_offset_hours * 60 * 60)
    |> Calendar.strftime("%d %b %Y, %H:%M")
    |> Kernel.<>(" WIB")
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for an activity form.
  """
  def change_activity(%Activity{} = activity, attrs \\ %{}) do
    Activity.changeset(activity, attrs)
  end
end
