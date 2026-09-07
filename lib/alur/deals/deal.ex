defmodule Alur.Deals.Deal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "deals" do
    field :title, :string
    field :amount, :integer
    field :notes, :string

    belongs_to :user, Alur.Accounts.User
    belongs_to :contact, Alur.Contacts.Contact
    belongs_to :pipeline_column, Alur.Deals.PipelineColumn
    has_many :activities, Alur.Activities.Activity
    has_many :next_actions, Alur.NextActions.NextAction

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a deal.
  """
  def changeset(deal, attrs) do
    attrs = sanitize_amount_attr(attrs)

    deal
    |> cast(attrs, [:title, :amount, :notes, :contact_id, :pipeline_column_id])
    |> validate_required([:title, :amount, :contact_id, :pipeline_column_id])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:notes, max: 10_000)
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:contact_id)
    |> foreign_key_constraint(:pipeline_column_id)
    |> foreign_key_constraint(:user_id)
  end

  defp sanitize_amount_attr(%{} = attrs) do
    case Map.fetch(attrs, "amount") do
      {:ok, val} when is_binary(val) ->
        Map.put(attrs, "amount", parse_amount(val))

      _ ->
        case Map.fetch(attrs, :amount) do
          {:ok, val} when is_binary(val) ->
            Map.put(attrs, :amount, parse_amount(val))

          _ ->
            attrs
        end
    end
  end

  defp sanitize_amount_attr(attrs), do: attrs

  defp parse_amount(val) do
    trimmed = String.trim(val)

    if trimmed == "" do
      nil
    else
      digits_only = String.replace(trimmed, ~r/[^\d]/, "")

      if digits_only == "" do
        nil
      else
        String.to_integer(digits_only)
      end
    end
  end
end
