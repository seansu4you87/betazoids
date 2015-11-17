defmodule Betazoids.FacebookTest do
  use ExUnit.Case, async: true

  test "#generate_long_token_url" do
    path = Betazoids.Facebook.generate_long_token_path("hello")
    assert path == "/oauth/access_token?client_id=848785661909846&client_secret=e0bf287aee9337835c77ce093776858f&fb_exchange_token=hello&grant_type=fb_exchange_token"
  end
end
