defmodule IdempotenceTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  alias Betazoids.Collector
  alias Betazoids.Facebook
  alias Betazoids.Repo

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Betazoids.Repo, [])
    :ok
  end

  def raw_daniel,  do: %{id: "15", name: "Daniel Gold"}
  def make_daniel, do: Collector.create_facebook_user(raw_daniel)

  test "#create will persist a new object since one doesn't exist" do
    {:ok, daniel} = make_daniel
    {:ok, collector_log} = Collector.create_collector_log
    changeset = Facebook.Message.changeset(%Facebook.Message{}, %{
      facebook_id: "12",
      user_id: daniel.id,
      text: "EAT SOME CARBS",
      created_at: Ecto.DateTime.utc,
      collector_log_id: collector_log.id,
      collector_log_fetch_count: 25,
    })

    {:ok, %{created: true, model: message}} = Idempotence.create(Repo, Facebook.Message, changeset, :facebook_id)

    query = from m in Facebook.Message,
         select: m
    [m] = Repo.all(query)

    assert m.facebook_id == "12"
    assert m.user_id == daniel.id
    assert m.text == "EAT SOME CARBS"
    assert m.collector_log_id == collector_log.id
    assert m.collector_log_fetch_count == 25
  end

  test "#create will not persist a new object since one exists already" do
    {:ok, daniel} = make_daniel
    {:ok, collector_log} = Collector.create_collector_log

    changeset = Facebook.Message.changeset(%Facebook.Message{}, %{
      facebook_id: "12",
      user_id: daniel.id,
      text: "EAT SOME CARBS",
      created_at: Ecto.DateTime.utc,
      collector_log_id: collector_log.id,
      collector_log_fetch_count: 25,
    })
    {:ok, _} = Repo.insert(changeset)

    {:ok, %{created: false, model: message}} = Idempotence.create(Repo, Facebook.Message, changeset, :facebook_id)

    query = from m in Facebook.Message,
         select: m
    ms = Repo.all(query)
    assert length(ms) == 1
    [m] = ms

    assert m.facebook_id == "12"
    assert m.user_id == daniel.id
    assert m.text == "EAT SOME CARBS"
    assert m.collector_log_id == collector_log.id
    assert m.collector_log_fetch_count == 25
  end

  test "#create when model exists but the attempted save isn't idempotent" do
    # buku boo boo
  end
end
