defmodule Betazoids.Facebook.UserTest do
  use Betazoids.ModelCase

  alias Betazoids.Facebook.User

  @valid_attrs %{facebook_id: "some content", name: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = User.changeset(%User{}, @invalid_attrs)
    refute changeset.valid?
  end
end
