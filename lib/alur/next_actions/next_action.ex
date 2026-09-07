defmodule Alur.NextActions.NextAction do
  @moduledoc """
  Schema for scheduled follow-up items (next actions) attached to deals.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Alur.Accounts.User
  alias Alur.Deals.Deal

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "next_actions" do
    field :what, :string
    field :due_date, :date
    field :due_time, :time
    field :due_at, :utc_datetime
    field :done, :boolean, default: false
    field :completed_at, :utc_datetime_usec

    # Virtual field for convenience / PRD parity
    field :due, :string, virtual: true

    belongs_to :user, User
    belongs_to :deal, Deal

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating or updating a next action.
  """
  def changeset(next_action, attrs) do
    attrs = sanitize_attrs(attrs)

    next_action
    |> cast(attrs, [
      :what,
      :due_date,
      :due_time,
      :due_at,
      :done,
      :completed_at,
      :deal_id,
      :user_id
    ])
    |> validate_required([:what, :deal_id, :user_id])
    |> validate_length(:what, min: 1, max: 500)
    |> normalize_due_fields()
    |> validate_required([:due_date, :due_at])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:deal_id)
  end

  @doc """
  Changeset for marking a next action as completed.
  """
  def complete_changeset(next_action, completed_at \\ nil) do
    completed_at = completed_at || DateTime.utc_now()
    change(next_action, done: true, completed_at: completed_at)
  end

  defp sanitize_attrs(%{} = attrs) do
    attrs
    |> sanitize_empty_time()
    |> sanitize_due_field()
  end

  defp sanitize_attrs(attrs), do: attrs

  defp sanitize_empty_time(attrs) do
    case Map.fetch(attrs, "due_time") do
      {:ok, ""} ->
        Map.put(attrs, "due_time", nil)

      _ ->
        case Map.fetch(attrs, :due_time) do
          {:ok, ""} -> Map.put(attrs, :due_time, nil)
          _ -> attrs
        end
    end
  end

  defp sanitize_due_field(attrs) do
    due_val = Map.get(attrs, "due") || Map.get(attrs, :due)

    cond do
      is_nil(due_val) ->
        attrs

      is_binary(due_val) ->
        trimmed = String.trim(due_val)
        parse_due_string(attrs, trimmed)

      match?(%Date{}, due_val) ->
        Map.put_new(attrs, :due_date, due_val)

      match?(%DateTime{}, due_val) ->
        Map.put_new(attrs, :due_at, due_val)

      true ->
        attrs
    end
  end

  defp parse_due_string(attrs, str) do
    cond do
      String.contains?(str, "T") ->
        case String.split(str, "T", parts: 2) do
          [date_part, time_part] ->
            time_clean = time_part |> String.replace("Z", "") |> String.slice(0, 8)

            attrs
            |> Map.put_new(:due_date, date_part)
            |> Map.put_new(:due_time, time_clean)

          _ ->
            attrs
        end

      String.contains?(str, " ") ->
        case String.split(str, " ", parts: 2) do
          [date_part, time_part] ->
            attrs
            |> Map.put_new(:due_date, date_part)
            |> Map.put_new(:due_time, String.slice(time_part, 0, 8))

          _ ->
            attrs
        end

      true ->
        Map.put_new(attrs, :due_date, str)
    end
  end

  defp normalize_due_fields(changeset) do
    due_at = get_field(changeset, :due_at)
    due_date = get_field(changeset, :due_date)
    due_time = get_field(changeset, :due_time)

    cond do
      due_at != nil && due_date == nil ->
        # Derive due_date and due_time from due_at (Asia/Jakarta is UTC+7)
        jakarta_dt = DateTime.add(due_at, 7 * 3600, :second)

        changeset
        |> put_change(:due_date, DateTime.to_date(jakarta_dt))
        |> put_change(:due_time, DateTime.to_time(jakarta_dt))

      due_date != nil &&
          (due_at == nil || get_change(changeset, :due_date) != nil ||
             get_change(changeset, :due_time) != nil) ->
        computed_due_at = compute_due_at(due_date, due_time)
        put_change(changeset, :due_at, computed_due_at)

      true ->
        changeset
    end
  end

  @doc """
  Computes the UTC datetime corresponding to a given due_date and optional due_time
  in Asia/Jakarta (UTC+7).
  """
  def compute_due_at(%Date{} = due_date, %Time{} = due_time) do
    naive = NaiveDateTime.new!(due_date, due_time)
    DateTime.from_naive!(naive, "Etc/UTC") |> DateTime.add(-7 * 3600, :second)
  end

  def compute_due_at(%Date{} = due_date, nil) do
    # When no time is given, action is due by end of the day in Jakarta (23:59:59)
    naive = NaiveDateTime.new!(due_date, ~T[23:59:59])
    DateTime.from_naive!(naive, "Etc/UTC") |> DateTime.add(-7 * 3600, :second)
  end
end
