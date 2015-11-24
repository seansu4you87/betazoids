defmodule Betazoids.CollectorLogTest do
  use Betazoids.ModelCase

  alias Betazoids.CollectorLog
  alias Betazoids.Repo

  @valid_attrs %{done: true, fetch_count: 42, message_count: 42, next_url: nil}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = CollectorLog.changeset(%CollectorLog{}, @valid_attrs)
    assert changeset.valid?
  end

  test "transactions when updating existing variable" do
    changeset = CollectorLog.changeset(%CollectorLog{}, %{})
    {:ok, collector_log} = Repo.insert(changeset)

    changeset2 = CollectorLog.changeset(collector_log, %{fetch_count: 2})

    # LESSON(yu): WOW okay this is huge.  You can change an outerscoped variable
    # inside of an anonymous function.  So instead, here I'm taking advantage
    # of the fact that `Repo.transaction` returns the value of the anonymous
    # function with `{:ok, value}`.  This was a huge time sink.  Remember this!
    {:ok, collector_log} = Repo.transaction fn ->
      {:ok, updated} = Repo.update(changeset2)
      updated
    end

    [refetched_log] = Repo.all(CollectorLog)

    assert collector_log.fetch_count == 2
    assert refetched_log.fetch_count == 2
  end

  test "changeset with invalid attributes" do
    changeset = CollectorLog.changeset(%CollectorLog{}, @invalid_attrs)

    # DETAIL(yu): You can create a CollectorLog with an empty hash
    assert changeset.valid?
  end
end
