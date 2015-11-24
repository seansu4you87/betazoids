defmodule Betazoids.Repo.Migrations.CreateAccessToken do
  use Ecto.Migration

  def change do
    create table(:facebook_access_tokens) do
      add :token, :text, null: false
      add :type, :string, default: ":short", null: false

      timestamps
    end

    create index(:facebook_access_tokens, [:token])
    create index(:facebook_access_tokens, [:type])
  end
end
