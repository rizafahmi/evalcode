defmodule Alur.AccountsTest do
  use Alur.DataCase, async: false

  import Ecto.Query

  alias Alur.Accounts
  alias Alur.Accounts.{Account, AccountToken}

  @valid_attrs %{
    email: "ari@example.com",
    password: "super secret 1234",
    password_confirmation: "super secret 1234"
  }

  describe "register_account/1" do
    test "registers an account with a hashed password" do
      assert {:ok, %Account{email: "ari@example.com"} = account} =
               Accounts.register_account(@valid_attrs)

      assert is_binary(account.hashed_password)
      assert account.hashed_password != @valid_attrs.password
      refute account.password
      assert Account.valid_password?(account, "super secret 1234")
      refute Account.valid_password?(account, "wrong password")
    end

    test "requires an email and a password" do
      assert {:error, changeset} = Accounts.register_account(%{})

      assert "can't be blank" in errors_on(changeset).email
      assert "can't be blank" in errors_on(changeset).password
    end

    test "rejects a malformed email" do
      attrs = Map.put(@valid_attrs, :email, "not-an-email")
      assert {:error, changeset} = Accounts.register_account(attrs)
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "rejects a short password" do
      attrs = Map.put(@valid_attrs, :password, "short")
      assert {:error, changeset} = Accounts.register_account(attrs)
      assert "should be at least 12 byte(s)" in errors_on(changeset).password
    end

    test "requires the password confirmation to match" do
      attrs = Map.put(@valid_attrs, :password_confirmation, "different password")
      assert {:error, changeset} = Accounts.register_account(attrs)
      assert "does not match password" in errors_on(changeset).password_confirmation
    end

    test "rejects a duplicate email" do
      assert {:ok, _account} = Accounts.register_account(@valid_attrs)
      assert {:error, changeset} = Accounts.register_account(@valid_attrs)
      assert "has already been taken" in errors_on(changeset).email
    end
  end

  describe "get_account_by_email_and_password/2" do
    test "returns the account for valid credentials" do
      {:ok, account} = Accounts.register_account(@valid_attrs)

      assert %Account{id: id} =
               Accounts.get_account_by_email_and_password("ari@example.com", "super secret 1234")

      assert id == account.id
    end

    test "returns nil for an unknown email or wrong password" do
      {:ok, _account} = Accounts.register_account(@valid_attrs)

      assert Accounts.get_account_by_email_and_password("nobody@example.com", "super secret 1234") ==
               nil

      assert Accounts.get_account_by_email_and_password("ari@example.com", "not the password") ==
               nil
    end
  end

  describe "session tokens" do
    setup do
      {:ok, account} = Accounts.register_account(@valid_attrs)
      %{account: account}
    end

    test "generates and verifies a session token", %{account: account} do
      token = Accounts.generate_account_session_token(account)

      assert {fetched_account, %AccountToken{context: "session"}} =
               Accounts.get_account_by_session_token(token)

      assert fetched_account.id == account.id
    end

    test "returns nil for an unknown token", %{account: account} do
      Accounts.generate_account_session_token(account)

      assert Accounts.get_account_by_session_token("bogus-token") == nil
    end

    test "deletes a session token", %{account: account} do
      token = Accounts.generate_account_session_token(account)
      assert Accounts.delete_account_session_token(token) == {1, nil}
      assert Accounts.get_account_by_session_token(token) == nil
    end

    test "expires session tokens older than the session validity window", %{account: account} do
      token = Accounts.generate_account_session_token(account)
      days = AccountToken.session_validity_in_days() + 1

      from(t in AccountToken, where: t.account_id == ^account.id)
      |> Repo.update_all(
        set: [
          inserted_at:
            DateTime.utc_now()
            |> DateTime.add(-days * 24 * 60 * 60, :second)
            |> DateTime.truncate(:second)
        ]
      )

      assert Accounts.get_account_by_session_token(token) == nil
    end
  end
end
