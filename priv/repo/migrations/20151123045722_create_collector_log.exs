defmodule Betazoids.Repo.Migrations.CreateCollectorLog do
  use Ecto.Migration

  def change do
    create table(:collector_logs) do
      add :message_count, :integer, null: false, default: 0
      add :fetch_count, :integer, null: false, default: 0
      add :next_url, :text
      add :done, :boolean, default: false, null: false

      timestamps
    end

    alter table(:facebook_messages) do
      add :collector_log_id, references(:collector_logs), null: false
      add :collector_log_fetch_count, :integer, null: false
    end
  end
end
