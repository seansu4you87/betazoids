defmodule Betazoids.Repo.Migrations.CreateFacebookUser do
  use Ecto.Migration

  def change do
    create table(:facebook_users) do
      add :name, :string, null: false
      add :facebook_id, :string, null: false

      timestamps
    end

    create index(:facebook_users, [:facebook_id], unique: true)
  end
end
