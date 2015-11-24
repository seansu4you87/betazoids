defmodule Betazoids.Collector do
  @moduledoc """
  Betazoids.Collector is a process that collects stats from the Betazoids
  messenger group

  It uses Betazoids.Facebook to interact with the Facebook Graph API.

  Collector consists to taking a short-lived token and extending it to a
  long-lived token.  This token is then used to periodically fetch data and
  results from the Betazoids messenger group

  Functions prefixed with `req_http_` are **impure** functions that call out
  via HTTP to Facebook.  These have been specifically noted so that you
  carefully tread around these.  Functions to process the responses of these
  HTTP requests are "pure" functions, but they still hit the database
  """

  use Supervisor

  import Ecto.Query

  alias Betazoids.CollectorLog
  alias Betazoids.Facebook
  alias Betazoids.Repo

  @betazoids_thread_id "438866379596318"
  # @sean_yu_long_lived_token "CAAMD90ZCeW1YBAE6tBMgPBeNhtbY0nUj6Il1A34dZAOqrSZCxwjsEu1uJjU8VQGrrOUc1DhLvXSfPCcW6ZBBDLsYG6ZAznoSi8l0t4qbKSDUZCSfmIFtDdnQMnGgkSa8DGAGkmpFMZAR4JIvAS4QmNgh2Q6e7VZCE04tWws4JGs2zdWf6taslUgKdCuHNXeEoqEZD"
  @graph_explorer_token "CAACEdEose0cBAEKVlkmLjnWLDdTwUjKM7KAO3e0whcrRu3VTJceZBdIZCJBZC84Ug61HsvVbxmKPdrBJ5tiWUbKytgP5EdVf7gcCej39AZBRduwIw7dD4pjNfyXLtBgZCNqpkCQzkvH59MTlyibsTZClZCZCaqdiG69kbOxoEYZBIhIOj4bJGS6epdiDGs9qJJW9YrBPWZBNdInQZDZD"

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: Betazoids.Collector])
  end

  def init([]) do
    children = [
      worker(Task, [__MODULE__, :collect_thread!, []], [name: Betazoids.Collector.ThreadProcessor])
    ]

    supervise(children, strategy: :one_for_one)
  end

  @doc """
  WARNING: impure function!

  Make a request to the betazoids thread and gets the head (latest)
  """
  def req_http_betazoids_head! do
    path = Facebook.thread(@betazoids_thread_id, @graph_explorer_token)
    case Facebook.get!(path) do
      %HTTPoison.Response{status_code: 200, body: body} ->
        comments = body.comments.data
        paging = body.comments.paging
        members = body.to.data
        last_updated = body.updated_time
        {:ok, %{comments: comments, paging: paging, members: members, last_updated: last_updated}}
      %HTTPoison.Response{status_code: 400, body: body} -> {:error, body}
      %HTTPoison.Error{reason: reason} -> {:error, reason}
    end
  end

  @doc """
  WARNING: impure function!

  Make a request to the betazoids at the given url
  """
  def req_http_betazoids_next!(next_url) do
    path = path_from_url(next_url)
    case Facebook.get!(path) do
      %HTTPoison.Response{status_code: 200, body: body} ->
        if length(body.data) == 0 do
          {:ok, %{done: true}}
        else
          {:ok, %{comments: body.data, paging: body.paging}}
        end
      %HTTPoison.Response{status_code: 400, body: body} -> {:error, body}
      %HTTPoison.Error{reason: reason} -> {:error, reason}
    end
  end

  def save_betazoid_members! do
    case req_http_betazoids_head! do
      {:ok, %{members: members}} ->
        db_members = members |> Enum.map fn(m) -> create_facebook_user(m) end
        {:ok, %{members: db_members}}
      {:error, message} ->
        {:error, message}
    end
  end

  def collect_thread! do
    case last_collector_log do
      []                          -> {:ok, collector_log} = fetch_head!
      [%CollectorLog{done: true}] -> {:ok, collector_log} = fetch_head!
      [last_log]                  -> collector_log = last_log
    end

    {:ok, _} = fetch_next!(collector_log)

    collect_thread!
  end

  def fetch_head! do
    {:ok, res} = req_http_betazoids_head!
    process_head(res.comments, res.paging.next)
  end

  def process_head(comments, next_url) do
    Repo.transaction fn ->
      {:ok, collector_log} = create_collector_log

      changeset = CollectorLog.changeset(collector_log, %{
        fetch_count: 1,
        message_count: length(comments),
        next_url: next_url
      })
      {:ok, collector_log} = Repo.update(changeset)

      process_comments(comments, collector_log)
      collector_log
    end
  end

  def fetch_next!(collector_log, tracer \\ []) do
    IO.puts "********************************************"
    IO.puts "tracer #{inspect tracer}"
    IO.puts "********************************************"

    if collector_log.done do
      IO.puts """
      done fetching #{collector_log.message_count} messages
      in #{collector_log.fetch_count} fetches
      """

      {:ok, collector_log}
    else
      {:ok, res} = req_http_betazoids_next!(collector_log.next_url)
      case res do
        %{done: true} -> process_done(collector_log)
        %{comments: comments, paging: paging} ->
          {:ok, collector_log} = process_next(collector_log, comments, paging.next)
      end

      :timer.sleep(1500)
      fetch_next!(collector_log, tracer ++ [collector_log.fetch_count])
    end
  end

  def process_done(collector_log) do
    changeset = CollectorLog.changeset(collector_log, %{done: true})
    Repo.update(changeset)
  end

  def process_next(collector_log, comments, next_url) do
    changeset = CollectorLog.changeset(collector_log, %{
      fetch_count: collector_log.fetch_count + 1,
      message_count: collector_log.message_count + length(comments),
      next_url: next_url
    })

    IO.puts """
    #{collector_log.fetch_count} -
    total: #{collector_log.message_count},
    add #{length(comments)} comments,
    first: #{List.first(comments).created_time}
    """

    Repo.transaction fn ->
      {:ok, updated} = Repo.update(changeset)
      process_comments(comments, updated)
      updated
    end
  end

  def last_collector_log do
    query = from cl in CollectorLog,
       order_by: [desc: cl.id],
          limit: 1,
         select: cl
    Repo.all(query)
  end

  def create_collector_log do
    changeset = CollectorLog.changeset(%CollectorLog{}, %{})
    Repo.insert(changeset)
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
        collector_log,
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
      created_at: tmp_time,
      collector_log_id: collector_log.id,
      collector_log_fetch_count: collector_log.fetch_count
    })

    Repo.insert(changeset)
  end

  def betazoids_member_cache do
    query = from u in Facebook.User,
         select: u

    Repo.all(query)
    |> Enum.reduce %{}, fn(u, cache) -> Map.put(cache, u.facebook_id, u) end
  end

  def process_comments(comments, collector_log) do
    ids = comments |> Enum.map(fn(c) -> c.id end) |> Enum.sort
    IO.puts "------------------------------------------------------------------------"
    IO.puts "FETCH COUNT: #{collector_log.fetch_count}"
    IO.puts "got #{inspect ids}"
    IO.puts "------------------------------------------------------------------------"

    cache = betazoids_member_cache
    Enum.each comments, fn(c) ->
      unless Map.has_key?(c, :message), do: c = Map.put(c, :message, nil)
      {:ok, _} = create_facebook_message(c, collector_log, cache)
    end
  end

  def path_from_url(url) do
    String.slice(url, 31..-1)
  end
end
