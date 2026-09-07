defmodule Alur.Accounts.AccountToken do
  @moduledoc """
  An account token used to keep accounts signed in between requests.

  Only opaque session tokens are stored. The plain token handed to the
  browser is never persisted; only its SHA-256 digest is.
  """

  use Ecto.Schema
  import Ecto.Query

  alias Alur.Accounts.Account
  alias Alur.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @session_validity_in_days 60

  schema "accounts_tokens" do
    field :token, :string
    field :context, :string
    field :sent_to, :string
    belongs_to :account, Account

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Builds a session token for the given account.

  Returns `{token, %AccountToken{}}` where `token` is the plain-text token
  to hand to the client and the struct carries only its hash.
  """
  def build_session_token(account) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    {token, %__MODULE__{account_id: account.id, token: hash_token(token), context: "session"}}
  end

  @doc """
  A query that finds a valid session token by its plain-text form and
  returns `{account, token}`. Age checks happen in the caller so no
  database-specific interval SQL is required.
  """
  def verify_session_token_query(token) do
    query =
      from token in __MODULE__,
        join: account in assoc(token, :account),
        where: token.context == "session" and token.token == ^hash_token(token),
        select: {account, token}

    {:ok, query}
  end

  @doc """
  Deletes the token record for the given plain-text session token.
  """
  def delete_session_token(token) do
    from(token in __MODULE__,
      where: token.context == "session" and token.token == ^hash_token(token)
    )
    |> Repo.delete_all()
  end

  def session_validity_in_days, do: @session_validity_in_days

  defp hash_token(token), do: :crypto.hash(:sha256, token) |> Base.encode16()
end
