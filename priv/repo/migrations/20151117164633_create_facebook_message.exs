defmodule Betazoids.Repo.Migrations.CreateFacebookMessage do
  use Ecto.Migration

  def change do
    create table(:facebook_messages) do
      add :text, :text
      add :facebook_id, :string, null: false
      add :created_at, :datetime, null: false
      add :user_id, references(:facebook_users), null: false

      timestamps
    end

    create index(:facebook_messages, [:facebook_id], unique: true)
  end
end
