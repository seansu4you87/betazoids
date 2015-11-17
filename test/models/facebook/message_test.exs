defmodule Betazoids.Facebook.MessageTest do
  use Betazoids.ModelCase

  alias Betazoids.Facebook

  @valid_attrs %{created_at: "2010-04-17 14:00:00", facebook_id: "some content", text: "some content", user_id: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Facebook.Message.changeset(%Facebook.Message{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Facebook.Message.changeset(%Facebook.Message{}, @invalid_attrs)
    refute changeset.valid?
  end
end
