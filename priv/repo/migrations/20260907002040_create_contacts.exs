defmodule Alur.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :email, :string
      add :phone, :string
      add :company, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:user_id])
    create index(:contacts, [:user_id, :name])
  end
end
