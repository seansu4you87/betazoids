defmodule Betazoids.Facebook do
  @moduledoc """
  Betazoids.Facebook is a simple wraper around the Facebook API

  Check out Betazoids.Collector for usage details
  """
  # HTTPoison setup
  use HTTPoison.Base

  def process_url(path) do
    scheme <> "://" <> base_url <> "/" <> version <> path
  end

  def process_response_body(body) do
    body
    |> Poison.decode!
    |> atomize
  end

  def atomize(map) when is_map(map) do
    Enum.reduce(map, Map.new, fn({k, v}, acc) ->
      Map.put(acc, String.to_atom(k), atomize(v)) end)
  end
  def atomize(arr) when is_list(arr) do
    Enum.map(arr, fn(v) -> atomize(v) end)
  end
  def atomize(any) do
    any
  end

  # Facebook setup
  defp scheme, do: "https"
  defp base_url, do: "graph.facebook.com"
  defp version, do: "v2.3" # read_mailbox permission is deprecated after 2.3
  defp app_id, do: "848785661909846"
  defp app_secret, do: "e0bf287aee9337835c77ce093776858f"

  @doc """
  Generates a graph API url that will extend a short-lived access token to a
  long-lived access token.

    * `short_token` - The short-lived token
  """
  def generate_long_token_path(short_token) do
    path = "oauth/access_token"
    params = %{
      grant_type:        "fb_exchange_token",
      client_id:         app_id,
      client_secret:     app_secret,
      fb_exchange_token: short_token
    }

    explode_path(path, params)
  end

  def thread(thread_id, access_token) do
    path = thread_id
    params = %{
      access_token: access_token
    }

    explode_path(path, params)
  end

  defp explode_path(path, params) do
    params_str = Enum.reduce(params, "", fn({key, val}, acc) ->
      acc <> to_string(key) <> "=" <> val <> "&"
    end)

    "/" <> path <> "?" <> String.slice(params_str, 0..-2)
  end
end
