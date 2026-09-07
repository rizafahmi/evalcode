defmodule Alur.Accounts do
  @moduledoc """
  The Accounts context manages accounts: registration with email and
  password, authentication, and the session tokens that keep an account
  signed in between requests.

  Every record in the rest of the app belongs to one of these accounts.
  """

  alias Alur.Accounts.{Account, AccountToken}
  alias Alur.Repo

  @doc """
  Gets an account by email.
  """
  def get_account_by_email(email) when is_binary(email) do
    Repo.get_by(Account, email: email)
  end

  @doc """
  Gets an account by email and password.

  Returns `nil` when the email is unknown or the password does not match.
  """
  def get_account_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    account = Repo.get_by(Account, email: email)
    if Account.valid_password?(account, password), do: account
  end

  @doc """
  Registers a new account with email, password, and password confirmation.

  Returns `{:ok, account}` or `{:error, changeset}`.
  """
  def register_account(attrs) do
    %Account{}
    |> Account.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for the registration form.
  """
  def change_account_registration(account \\ %Account{}, attrs \\ %{}) do
    Account.registration_changeset(account, attrs)
  end

  @doc """
  Generates a session token for the given account and persists its hash.

  Returns the plain-text token to store in the session.
  """
  def generate_account_session_token(account) do
    {token, account_token} = AccountToken.build_session_token(account)
    Repo.insert!(account_token)
    token
  end

  @doc """
  Gets the account for the given session token.

  Returns `{account, token}` where `token` is the `%AccountToken{}` struct,
  or `nil` when the token is unknown or has expired.
  """
  def get_account_by_session_token(token) do
    with {:ok, query} <- AccountToken.verify_session_token_query(token),
         {account, account_token} <- Repo.one(query),
         true <- session_token_current?(account_token) do
      {account, account_token}
    else
      _ -> nil
    end
  end

  @doc """
  Deletes the session token for the given plain-text token, if it exists.
  """
  def delete_account_session_token(token) do
    AccountToken.delete_session_token(token)
  end

  defp session_token_current?(%AccountToken{inserted_at: inserted_at}) do
    days = AccountToken.session_validity_in_days()

    DateTime.compare(
      inserted_at,
      DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)
    ) == :gt
  end
end
