defmodule Betazoids.FacebookUserTest do
  use Betazoids.ModelCase

  alias Betazoids.FacebookUser

  @valid_attrs %{facebook_id: "some content", name: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = FacebookUser.changeset(%FacebookUser{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = FacebookUser.changeset(%FacebookUser{}, @invalid_attrs)
    refute changeset.valid?
  end
end
