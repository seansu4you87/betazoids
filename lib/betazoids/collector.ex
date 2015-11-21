defmodule Betazoids.Collector do
  @moduledoc """
  Betazoids.Collector is a process that collects stats from the Betazoids
  messenger group

  It uses Betazoids.Facebook to interact with the Facebook Graph API.

  Collector consists to taking a short-lived token and extending it to a
  long-lived token.  This token is then used to periodically fetch data and
  results from the Betazoids messenger group
  """

  use Supervisor

  def start_link(table) do
    Supervisor.start_link(__MODULE__, [table], [name: Betazoids.Collector])
  end

  def init([table]) do
    :ets.insert(table, {"total", "0"})
    :ets.insert(table, {"count", "0"})

    children = [
      worker(Task, [__MODULE__, :watch_thread, [table]], [name: Betazoids.Collector.ThreadProcessor])
    ]

    supervise(children, strategy: :one_for_one)
  end

  def say_hello(table) do
    [{"phrase", phrase}] = :ets.lookup(table, "phrase")
    IO.puts "#{inspect self}: #{phrase}"
    :ets.insert(table, {"phrase", "#{phrase} #{phrase}"})


    :timer.sleep(1500)
    say_hello(table)
  end

  def watch_thread(table) do
    :timer.sleep(1500)
    case :ets.lookup(table, "next") do
      [{"next", next}] ->
        {:ok, %{next: next, comments: comments}} = fetch_next(next)

        {total, _} = Integer.parse(elem(retrieve_key(table, "total"), 1))
        total = total + length(comments)
        store_key(table, "total", to_string(total))

        {count, _} = Integer.parse(elem(retrieve_key(table, "count"), 1))
        count = count + 1
        store_key(table, "count", to_string(count))

        first = List.first(comments)
        IO.puts "#{count} - total: #{total}, add #{length(comments)} comments, first: #{first.created_time}"

        process_comments(comments)
        store_next(table, next)
        watch_thread(table)
      [] ->
        case check_betazoids do
          {:ok, res} ->
            process_comments(res.comments)
            store_next(table, res.paging.next)
            watch_thread(table)
          {:error, body} ->
            IO.puts body
            raise "Error in #check_betazoids"
        end
    end
  end

  def store_next(table, next) do
    store_key(table, "next", next)
  end

  def retrieve_key(table, key) do
    case :ets.lookup(table, key) do
      [] -> {:error, "#{key} does not exist"}
      [{key, value}] -> {:ok, value}
    end
  end

  def store_key(table, key, value) do
    :ets.insert(table, {key, value})
  end

  alias Betazoids
  alias Betazoids.Repo
  alias Betazoids.Facebook
  import Ecto.Query

  def fetch_next(next_url) do
    next_path = path_from_url(next_url)
    case Facebook.get!(next_path) do
      %HTTPoison.Response{status_code: 200, body: body} ->
        comments = body.data
        paging = body.paging

        {:ok, %{next: paging.next, comments: comments}}
      %HTTPoison.Response{status_code: 400, body: body} ->
        {:error, %{message: body}}
      %HTTPoison.Error{reason: reason} ->
        {:error, %{message: reason}}
    end
  end

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

  def check_betazoids do
    path = Facebook.thread(betazoids_thread_id, graph_explorer_token)
    case Facebook.get!(path) do
      %HTTPoison.Response{status_code: 200, body: body} ->
        comments = body.comments.data
        paging = body.comments.paging
        members = body.to.data
        last_updated = body.updated_time
        {:ok, %{comments: comments, paging: paging, members: members, last_updated: last_updated}}
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

  def betazoids_member_cache do
    query = from u in Facebook.User,
         select: u

    Repo.all(query)
    |> Enum.reduce %{}, fn(u, cache) -> Map.put(cache, u.facebook_id, u) end
  end

  def process_comments(comments) do
    # Enum.each comments, fn(c) -> IO.puts "processing #{c.id} from #{c.from.name} at: #{c.created_time}" end
    cache = betazoids_member_cache
    # Enum.each comments, fn(c) -> create_facebook_message(c, cache) end
  end

  def betazoids_thread_id, do: "438866379596318"
  def sean_yu_long_lived_token, do: "CAAMD90ZCeW1YBAE6tBMgPBeNhtbY0nUj6Il1A34dZAOqrSZCxwjsEu1uJjU8VQGrrOUc1DhLvXSfPCcW6ZBBDLsYG6ZAznoSi8l0t4qbKSDUZCSfmIFtDdnQMnGgkSa8DGAGkmpFMZAR4JIvAS4QmNgh2Q6e7VZCE04tWws4JGs2zdWf6taslUgKdCuHNXeEoqEZD"
  def graph_explorer_token, do: "CAACEdEose0cBAAEhWbZBy4ZC9xZBmeciEugZB3lcHFvdKRw8fYl2Bm8CXSwGGJbjMyV84IY6IZBMb5oM4cI7k2GUkc4cjoYcYCOWhqwysPe2r67PUiSNaKk1lteLYUbsJkILgk57J1c1aJz75LfxI87cJ5AWsvAw04j7ZBmXJQc1TZCuzybj9SDW1K920znQlB5ta1rXp1FPQZDZD"

  defp path_from_url(url) do
    String.slice(url, 31..-1)
  end

end
