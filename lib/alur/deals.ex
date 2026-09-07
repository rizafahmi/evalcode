defmodule Alur.Deals do
  @moduledoc """
  The Deals context manages the deals a signed-in account keeps on its
  pipeline, plus the fixed pipeline columns those deals sit on.

  Every read takes the owning `%Alur.Accounts.Account{}` so one account can
  never list, read, edit, or delete another account's deals. A deal is always
  anchored to a contact of the same account, so creating one requires the
  account-scoped `%Alur.Contacts.Contact{}` as well.
  """

  import Ecto.Query, warn: false

  alias Alur.Accounts.Account
  alias Alur.Activities
  alias Alur.Contacts.Contact
  alias Alur.Deals.{Deal, PipelineColumn}
  alias Alur.Repo

  # The activity-log line written when a deal is created. Every deal therefore
  # opens with a "created" entry on its log.
  @created_description "Deal created"

  @doc """
  The fixed pipeline columns in board order (Lead → Lost).
  """
  def list_pipeline_columns do
    Repo.all(from(c in PipelineColumn, order_by: [asc: c.order]))
  end

  @doc """
  Returns the deals that belong to `account` and are anchored to `contact_id`,
  newest first, with their contact and column preloaded.
  """
  def list_contact_deals(%Account{id: account_id}, contact_id) do
    Repo.all(
      from(d in Deal,
        where: d.account_id == ^account_id and d.contact_id == ^contact_id,
        order_by: [desc: d.inserted_at],
        preload: [:contact, :pipeline_column]
      )
    )
  end

  @doc """
  Returns every deal that belongs to `account`, newest first, with its contact
  and pipeline column preloaded.

  This is the account-wide fetch that powers the pipeline board (each column is
  a slice of this list), and the seam later account-wide views and the JSON API
  build on.
  """
  def list_deals(%Account{id: account_id}) do
    Repo.all(
      from(d in Deal,
        where: d.account_id == ^account_id,
        order_by: [desc: d.inserted_at],
        preload: [:contact, :pipeline_column]
      )
    )
  end

  @doc """
  Gets one of the fixed pipeline columns by id, or `nil` when the id is
  unknown. Columns are reference data shared by every account.
  """
  def get_pipeline_column(id) do
    Repo.get(PipelineColumn, id)
  end

  @doc """
  Moves a deal to another pipeline column.

  `deal_id` is resolved account-scoped (a deal that is unknown or belongs to
  another account is not found) and the target column must be one of the fixed
  seeded columns. Moving goes through the same changeset path as editing a
  deal on the deal page, and every successful move to a *different* column
  writes a `Moved from … to …` line on the deal's activity log.

  Returns `{:ok, deal}` on success, `{:error, :not_found}` when the deal or
  target column does not exist, or `{:error, changeset}` when the change is
  invalid.
  """
  def move_deal(%Account{} = account, deal_id, pipeline_column_id) do
    with %Deal{} = deal <- get_deal(account, deal_id),
         %PipelineColumn{} = column <- get_pipeline_column(pipeline_column_id) do
      update_deal(deal, %{pipeline_column_id: column.id})
    else
      nil -> {:error, :not_found}
      {:error, _changeset} = error -> error
    end
  end

  @doc """
  Gets a single deal, but only if it belongs to `account`, with its contact and
  column preloaded.

  Returns `nil` when the id is unknown or the deal belongs to another account.
  """
  def get_deal(%Account{id: account_id}, id) do
    Repo.get_by(Deal, id: id, account_id: account_id)
    |> Repo.preload([:contact, :pipeline_column])
  end

  @doc """
  Creates a deal owned by `account` and anchored to `contact` (which must
  belong to the same account; the caller fetches it through the account-scoped
  `Alur.Contacts.get_contact/2`).

  The deal and its opening activity-log line (`Deal created`) are written in
  one transaction, so a deal never exists without its created line.

  Returns `{:ok, deal}` or `{:error, changeset}`.
  """
  def create_deal(%Account{id: account_id}, %Contact{id: contact_id}, attrs \\ %{}) do
    Repo.transaction(fn ->
      with {:ok, deal} <-
             %Deal{account_id: account_id, contact_id: contact_id}
             |> change_deal(attrs)
             |> Repo.insert(),
           {:ok, _activity} <- Activities.log(deal, @created_description) do
        deal
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Updates the editable fields of a deal (title, amount, column, notes).

  The deal must have been fetched through `get_deal/2` (or an equivalent
  account-scoped query) so ownership and anchoring are never changed here.
  When the update actually moves the deal to another pipeline column — whether
  through the deal-edit page or through `move_deal/3` — a `Moved from … to …`
  line is written on the deal's activity log.

  Returns `{:ok, deal}` or `{:error, changeset}`.
  """
  def update_deal(%Deal{} = deal, attrs) do
    case change_deal(deal, attrs) |> Repo.update() do
      {:ok, updated} ->
        log_column_move(deal, updated)
        {:ok, updated}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a deal. Same ownership caveat as `update_deal/2`.
  """
  def delete_deal(%Deal{} = deal) do
    Repo.delete(deal)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for a deal form.
  """
  def change_deal(%Deal{} = deal, attrs \\ %{}) do
    Deal.changeset(deal, attrs)
  end

  # When an update really moved the deal onto another pipeline column (Ecto
  # only reports a change when the value differs, so dropping a card on the
  # column it is already on writes nothing), write the matching activity-log
  # line. Every column change funnels through here: the deal-edit page calls
  # update_deal/2 directly, move_deal/3 sends board drags (and later the JSON
  # API) through the same path, and unknown column names simply mean no line —
  # a failed lookup can never crash a deal edit.
  defp log_column_move(%Deal{} = before, %Deal{pipeline_column_id: new_column_id})
       when new_column_id != before.pipeline_column_id do
    with old_name when is_binary(old_name) <- column_name(before),
         %PipelineColumn{name: new_name} <- get_pipeline_column(new_column_id) do
      Activities.log(before, "Moved from #{old_name} to #{new_name}")
    else
      _ -> :ok
    end
  end

  defp log_column_move(_before, _updated), do: :ok

  # The name of the column a deal sits on, using the preloaded association
  # (deal pages and move_deal/3 fetch deals through get_deal/2 which preloads
  # it) or falling back to the column itself when the deal is bare.
  defp column_name(%Deal{pipeline_column: %PipelineColumn{name: name}}) when is_binary(name) do
    name
  end

  defp column_name(%Deal{pipeline_column_id: column_id}) when is_binary(column_id) do
    case get_pipeline_column(column_id) do
      %PipelineColumn{name: name} -> name
      nil -> nil
    end
  end

  defp column_name(_deal), do: nil

  @doc """
  Formats an integer amount of Indonesian Rupiah the way the app shows money
  everywhere: the `Rp` prefix and Indonesian dot grouping.

      iex> Alur.Deals.format_idr(15_000_000)
      "Rp 15.000.000"

  A missing value is shown as an em dash.
  """
  def format_idr(amount) when is_integer(amount) and amount >= 0 do
    "Rp " <> group_thousands(amount)
  end

  def format_idr(_amount), do: "—"

  defp group_thousands(amount) do
    digits = Integer.to_string(amount)
    Regex.replace(~r/\B(?=(\d{3})+(?!\d))/, digits, ".")
  end
end
