defmodule Betazoids.Facebook.AccessTokenTest do
  use Betazoids.ModelCase

  use Pavlov.Case, async: true
  import Pavlov.Syntax.Expect

  alias Betazoids.Facebook.AccessToken

  describe "#changeset" do
    let :valid_attrs do
      %{token: "some content", type: "some content"}
    end

    let :invalid_attrs do
      %{}
    end

    context "valid attributes" do
      it "is valid" do
        changeset = AccessToken.changeset(%AccessToken{}, valid_attrs)
        expect changeset.valid? |> to_be_true
      end
    end

    context "invalid attributes" do
      it "is valid" do
        changeset = AccessToken.changeset(%AccessToken{}, invalid_attrs)
        expect changeset.valid? |> not_to_be_true
      end
    end
  end
end
