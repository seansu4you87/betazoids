defmodule Betazoids.FacebookTest do
  use Pavlov.Case, async: true
  import Pavlov.Syntax.Expect

  describe "#generate_long_token_url" do
    let :path do
      Betazoids.Facebook.generate_long_token_path("hello")
    end

    it "generates with a proper client id & secret" do
      expect Betazoids.Facebook.generate_long_token_path("hello")
      |> to_eq "/oauth/access_token?client_id=848785661909846" <>
        "&client_secret=e0bf287aee9337835c77ce093776858f" <>
        "&fb_exchange_token=hello" <>
        "&grant_type=fb_exchange_token"
    end
  end
end
