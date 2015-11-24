defmodule Betazoids.Facebook.AccessTokenTest do
  use Betazoids.ModelCase

  alias Betazoids.Facebook.AccessToken

  @valid_attrs %{token: "some content", type: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = AccessToken.changeset(%AccessToken{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = AccessToken.changeset(%AccessToken{}, @invalid_attrs)
    refute changeset.valid?
  end
end
