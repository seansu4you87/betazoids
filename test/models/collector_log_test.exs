defmodule Betazoids.CollectorLogTest do
  use Betazoids.ModelCase

  alias Betazoids.CollectorLog

  @valid_attrs %{done: true, fetch_count: 42, message_count: 42, next_url: nil}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = CollectorLog.changeset(%CollectorLog{}, @valid_attrs)
    assert changeset.valid?
  end

  # You can create a CollectorLog with an empty hash
  # test "changeset with invalid attributes" do
  #   changeset = CollectorLog.changeset(%CollectorLog{}, @invalid_attrs)
  #   refute changeset.valid?
  # end
end
