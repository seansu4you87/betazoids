defmodule Betazoids.Collector do
  @moduledoc """
  Betazoids.Collector is a process that collects stats from the Betazoids
  messenger group

  It uses Betazoids.Facebook to interact with the Facebook Graph API.

  Collector consists to taking a short-lived token and extending it to a
  long-lived token.  This token is then used to periodically fetch data and
  results from the Betazoids messenger group
  """

  alias Betazoids
  alias Betazoids.Repo
  alias Betazoids.Facebook
  import Ecto.Query

  def acquire_long_token(short_token) do
    path = Facebook.generate_long_token_path(short_token)
    case Facebook.get!(path) do
      %HTTPoison.Response{status_code: 200, body: body} ->
        {:ok, %{long_token: body.access_token, expires_in: body.expires_in}}
      %HTTPoison.Response{status_code: 400, body: body} ->
        {:error, body}
      %HTTPoison.Error{reason: reason} ->
        {:error, reason}
    end
  end

  def grab_comments do
    case check_betazoids do
      {:ok, res} ->
        fetch_comments(res.paging.next, 2, res.comments)
      {:error, res} ->
        IO.puts "FUCK ERROR: #{res}"
    end
  end

  def check_betazoids do
    path = Facebook.thread(betazoids_thread_id, graph_explorer_token)
    case Facebook.get!(path) do
      %HTTPoison.Response{status_code: 200, body: body} ->
        comments = body.comments.data
        paging = body.comments.paging # TODO(yu): go .next to hit the next line
        members = body.to.data
        last_updated = body.updated_time
        {:ok, %{comments: comments, paging: paging, members: members, last_updated: last_updated}}
      %HTTPoison.Response{status_code: 400, body: body} ->
        {:error, body}
      %HTTPoison.Error{reason: reason} ->
        {:error, reason}
    end
  end

  defp fetch_comments(next_url, count, memo \\ []) do
    next_path = path_from_url(next_url)
    case Facebook.get!(next_path) do
      %HTTPoison.Response{status_code: 200, body: body} ->
        comments = body.data
        paging = body.paging # TODO(yu): go .next to hit the next line

        first = List.first(comments)
        IO.puts "fetch number #{count}: got #{length(comments)} comments, first: #{first.created_time}"

        if length(comments) > 0 do
          new_comments = List.flatten([comments, memo])
          :timer.sleep(5000)
          fetch_comments(paging.next, count+1, new_comments)
          {:ok, %{comments: comments, paging: paging}}
        else
          {:ok, %{comments: memo}}
        end
      %HTTPoison.Response{status_code: 400, body: body} ->
        {:error, body}
      %HTTPoison.Error{reason: reason} ->
        {:error, reason}
    end
  end

  def save_betazoid_members do
    case check_betazoids do
      {:ok, %{members: members}} ->
        {:ok, %{members: Enum.map(members, fn(member_hash) ->
          create_facebook_user(member_hash) end)}}
      {:error, message} ->
        {:error, message}
    end
  end

  def create_facebook_user(%{id: id, name: name}) do
    changeset = Facebook.User.changeset(%Facebook.User{}, %{
      facebook_id: id,
      name: name})

    case Repo.insert(changeset) do
      {:ok, user} ->
        IO.puts "YAY created #{user.name}"
        {:ok, user}
      {:error, changeset} ->
        IO.puts "BOO errored"
        IO.puts Enum.map(changeset.errors, fn({k,v}) -> "#{k} #{v}" end)
        {:error, changeset}
    end
  end

  def create_facebook_message(%{
          id: id,
          from: from_hash,
          message: message,
          created_time: created_time},
        user_cache \\ %{}) do
    user_id = case user_cache[from_hash.id] do
      %Facebook.User{id: id} -> id
      nil ->
        query = from u in Facebook.User,
              where: u.facebook_id == ^from_hash.id,
             select: u
        case Repo.all(query) do
          [] -> raise "No user found for #{from_hash.id}, shouldn't happen"
          [%Facebook.User{id: id}] -> id
        end
    end

    # TODO(yu): get a real time
    tmp_time = Ecto.DateTime.from_erl(:calendar.now_to_datetime(:os.timestamp))
    changeset = Facebook.Message.changeset(%Facebook.Message{}, %{
      facebook_id: id,
      user_id: user_id,
      text: message,
      created_at: tmp_time
    })

    case Repo.insert(changeset) do
      {:ok, message} ->
        IO.puts "YAY created"
        {:ok, message}
      {:error, changeset} ->
        IO.puts "BOO errored"
        IO.puts Enum.map(changeset.errors, fn({k,v}) -> "#{k} #{v}" end)
        {:error, changeset}
    end
  end

  def betazoids_thread_id, do: "438866379596318"
  def sean_yu_long_lived_token, do: "CAAMD90ZCeW1YBAE6tBMgPBeNhtbY0nUj6Il1A34dZAOqrSZCxwjsEu1uJjU8VQGrrOUc1DhLvXSfPCcW6ZBBDLsYG6ZAznoSi8l0t4qbKSDUZCSfmIFtDdnQMnGgkSa8DGAGkmpFMZAR4JIvAS4QmNgh2Q6e7VZCE04tWws4JGs2zdWf6taslUgKdCuHNXeEoqEZD"
  def graph_explorer_token, do: "CAACEdEose0cBAIEWxJcwR5JRFZCfKk1KoRy2ZCaktNPZAN3CFFLMyFGhaX3Gf0WidMom8EyOwAFxUhklKpZBwn1okMJPwt6RBbZCJJVa1uxXOisoZAghTS4yjZB28qZAki0vSAyi1qkdDZCRObwR7Srh7Y6WTtyC3m42nYrZCiDy9Qv4uo9JfikCznNd1yfFwAE1zmv7afAGYrRAZDZD"

  defp path_from_url(url) do
    String.slice(url, 31..-1)
  end

end
