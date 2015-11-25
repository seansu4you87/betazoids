defmodule IdempotenceTest do
  use ExUnit.Case

  import Ecto.Query

  alias Betazoids.Collector
  alias Betazoids.Facebook
  alias Betazoids.Repo

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Betazoids.Repo, [])
    :ok
  end

  def raw_daniel,  do: %{id: "15", name: "Daniel Gold"}
  def raw_ben,     do: %{id: "12", name: "Ben Cunningham"}
  def make_daniel, do: Collector.create_facebook_user(raw_daniel)
  def make_ben,    do: Collector.create_facebook_user(raw_ben)

  def make_message_changeset(user, collector_log) do
    Facebook.Message.changeset(%Facebook.Message{}, %{
      facebook_id: "12",
      user_id: user.id,
      text: "EAT SOME CARBS",
      created_at: Ecto.DateTime.utc,
      collector_log_id: collector_log.id,
      collector_log_fetch_count: 25,
    })
  end

  test "#create will persist a new object since one doesn't exist" do
    {:ok, daniel} = make_daniel
    {:ok, collector_log} = Collector.create_collector_log
    changeset = make_message_changeset(daniel, collector_log)

    {:ok, %{created: true, model: _}} = Idempotence.create(Repo, Facebook.Message, :facebook_id, changeset)

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
    changeset = make_message_changeset(daniel, collector_log)

    {:ok, _} = Repo.insert(changeset)

    {:ok, %{created: false, model: _}} = Idempotence.create(Repo, Facebook.Message, :facebook_id, changeset)

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
    {:ok, daniel} = make_daniel
    {:ok, collector_log} = Collector.create_collector_log
    changeset = make_message_changeset(daniel, collector_log)

    {:ok, _} = Repo.insert(changeset)

    {:ok, next_collector_log} = Collector.create_collector_log
    changeset = %{changeset|changes: %{changeset.changes|collector_log_id: next_collector_log.id}}

    assert_raise Idempotence.DifferentValuesError, fn ->
      Idempotence.create(Repo, Facebook.Message, :facebook_id, changeset)
    end

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

  test "#create with a before_callback" do
    {:ok, daniel} = make_daniel
    {:ok, collector_log} = Collector.create_collector_log
    changeset = make_message_changeset(daniel, collector_log)

    {:ok, %{created: true, model: _}} = Idempotence.create(
      Repo,
      Facebook.Message,
      :facebook_id,
      changeset,
      before_callback: fn -> make_ben end,
    )

    query = from u in Facebook.User,
          where: u.facebook_id == ^raw_ben.id,
         select: u
    assert length(Repo.all(query)) == 1

    query = from m in Facebook.Message,
         select: m
    [m] = Repo.all(query)

    assert m.facebook_id == "12"
    assert m.user_id == daniel.id
    assert m.text == "EAT SOME CARBS"
    assert m.collector_log_id == collector_log.id
    assert m.collector_log_fetch_count == 25
  end

  test "#create with a before_callback when model is already created" do
    {:ok, daniel} = make_daniel
    {:ok, collector_log} = Collector.create_collector_log
    changeset = make_message_changeset(daniel, collector_log)

    {:ok, _} = Repo.insert(changeset) # DETAIL(yu): creating the model first

    {:ok, %{created: false, model: _}} = Idempotence.create(
      Repo,
      Facebook.Message,
      :facebook_id,
      changeset,
      before_callback: fn -> make_ben end,
    )

    query = from u in Facebook.User,
          where: u.facebook_id == ^raw_ben.id,
         select: u
    assert length(Repo.all(query)) == 1

    query = from m in Facebook.Message,
         select: m
    [m] = Repo.all(query)

    assert m.facebook_id == "12"
    assert m.user_id == daniel.id
    assert m.text == "EAT SOME CARBS"
    assert m.collector_log_id == collector_log.id
    assert m.collector_log_fetch_count == 25
  end

  test "#create with a before_callback when model is already created, but not idempotently, does not execute the callback" do
    {:ok, daniel} = make_daniel
    {:ok, collector_log} = Collector.create_collector_log
    changeset = make_message_changeset(daniel, collector_log)

    {:ok, _} = Repo.insert(changeset) # DETAIL(yu): creating the model first

    {:ok, next_collector_log} = Collector.create_collector_log
    changeset = %{changeset|changes: %{changeset.changes|collector_log_id: next_collector_log.id}}

    assert_raise Idempotence.DifferentValuesError, fn ->
      Idempotence.create(Repo, Facebook.Message, :facebook_id, changeset, before_callback: fn -> make_ben end)
    end

    query = from u in Facebook.User,
          where: u.facebook_id == ^raw_ben.id,
         select: u
    assert length(Repo.all(query)) == 0

    query = from m in Facebook.Message,
         select: m
    [m] = Repo.all(query)

    assert m.facebook_id == "12"
    assert m.user_id == daniel.id
    assert m.text == "EAT SOME CARBS"
    assert m.collector_log_id == collector_log.id
    assert m.collector_log_fetch_count == 25
  end
end
