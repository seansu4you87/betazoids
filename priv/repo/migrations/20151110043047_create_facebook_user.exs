defmodule Betazoids.Repo.Migrations.CreateFacebookUser do
  use Ecto.Migration

  def change do
    create table(:facebook_users) do
      add :name, :string
      add :facebook_id, :string

      timestamps
    end

  end
end
