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
    path = Facebook.thread(@betazoids_thread_id, graph_explorer_access_token)
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
    path = path_from_url(reauth_url(next_url))
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

  @doc """
  This is main task of the Collector.  It starts from the head, and collect
  each message all the way to the beginning
  """
  def collect_thread! do
    case last_collector_log do
      []                          -> {:ok, collector_log} = fetch_head!
      [%CollectorLog{done: true}] -> {:ok, collector_log} = fetch_head!
      [last_log]                  -> collector_log = last_log
    end

    {:ok, collector_log} = fetch_next!(collector_log)
    IO.puts "**********************************************************"
    IO.puts """
    CollectorLog #{collector_log.id}
    has fetched #{collector_log.fetch_count} times,
    fetching #{collector_log.message_count} message
    """
    IO.puts "**********************************************************"
  end

  def fetch_head! do
    {:ok, res} = req_http_betazoids_head!
    process_head(res.comments, res.paging.next)
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

  def process_head(comments, next_url) do
    Repo.transaction fn ->
      {:ok, collector_log} = create_collector_log

      changeset = CollectorLog.changeset(collector_log, %{
        fetch_count: 1,
        # message_count: length(comments),
        next_url: next_url
      })
      {:ok, collector_log} = Repo.update(changeset)

      process_comments(comments, collector_log)
      collector_log
    end
  end

  def process_done(collector_log) do
    changeset = CollectorLog.changeset(collector_log, %{done: true})
    Repo.update(changeset)
  end

  def process_next(collector_log, comments, next_url) do
    changeset = CollectorLog.changeset(collector_log, %{
      fetch_count: collector_log.fetch_count + 1,
      # message_count: collector_log.message_count + length(comments),
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
      {:ok, updated} = process_comments(comments, updated)
      updated
    end
  end

  def process_comments_old(comments, collector_log, next_url) do
    cache = betazoids_member_cache
    Enum.each comments, fn(c) ->
      unless Map.has_key?(c, :message), do: c = Map.put(c, :message, nil)
      {:ok, {message, collector_log}} = create_facebook_message(c, collector_log, cache)
    end

    {:ok, collector_log}
  end

  def process_comments([], collector_log, _cache) do
    {:ok, collector_log}
  end

  def process_comments(comments, collector_log, cache \\ %{}) do
    if cache == %{}, do: cache = betazoids_member_cache

    [head|tail] = comments
    unless Map.has_key?(head, :message), do: head = Map.put(head, :message, nil)

    {:ok, {message, collector_log}} = create_facebook_message(head, collector_log, cache)
    process_comments(tail, collector_log, cache)
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
    user_id = database_id_from_cache(user_cache, from_hash.id)
    {:ok, ecto_date} = parse_date(created_time)
    changeset = Facebook.Message.changeset(%Facebook.Message{}, %{
      facebook_id: id,
      user_id: user_id,
      text: message,
      created_at: ecto_date,
      collector_log_id: collector_log.id,
      # DETAIL(yu): We increment the fetch count because we don't persist an
      # updated fetch count on the CollectorLog until all of the comments for a
      # fetch batch have been persisted
      collector_log_fetch_count: collector_log.fetch_count + 1
    })

    after_callback = fn ->
      cs = CollectorLog.changeset(collector_log, %{message_count: collector_log.message_count + 1})
      {:ok, collector_log} = Repo.update(cs)
      collector_log
    end

    case Idempotence.create(
      Repo,
      Facebook.Message,
      :facebook_id,
      changeset,
      after_callback: after_callback
    ) do
      # TODO(yu): this is just plain wrong right?  We don't want the
      # after_callback to execute if it fails to create.
      # Let's write a test for this in the CollectorTest
      {:ok, %{created: true, model: message, callbacks: callbacks}} ->
        {:ok, {message, callbacks.after}}
      {:ok, %{created: false, model: message, callbacks: callbacks}} ->
        {:ok, {message, collector_log}}
    end
  end

  defp database_id_from_cache(cache, facebook_id) do
    case cache[facebook_id] do
      %Facebook.User{id: id} -> id
      nil ->
        query = from u in Facebook.User,
              where: u.facebook_id == ^facebook_id,
             select: u
        case Repo.all(query) do
          [] -> raise "No user found for #{facebook_id}, shouldn't happen"
          [%Facebook.User{id: id}] -> id
        end
    end
  end

  def betazoids_member_cache do
    query = from u in Facebook.User,
         select: u

    Repo.all(query)
    |> Enum.reduce %{}, fn(u, cache) -> Map.put(cache, u.facebook_id, u) end
  end

  def path_from_url(url) do
    String.slice(url, 31..-1)
  end

  def parse_date(raw_date) do
    {:ok, timex_date} = Timex.DateFormat.parse(raw_date, "{ISO}")
    {:ok, ecto_raw_date} = Timex.DateFormat.format(timex_date, "{ISOz}")
    Ecto.DateTime.cast(ecto_raw_date)
  end

  def graph_explorer_access_token do
    query = from fat in Facebook.AccessToken,
       order_by: [desc: fat.id],
          limit: 1,
         select: fat
    [%Facebook.AccessToken{token: token}] = Repo.all(query)
    token
  end

  def reauth_url(next_url) do
    [base_url, query_params] = String.split(next_url, "?")
    base_url <> "?" <> (query_params
    |> String.split("&")
    |> Enum.map_join("&", fn(params) ->
      case params do
        "access_token=" <> _ -> "access_token=#{graph_explorer_access_token}"
        anything -> anything
      end
    end))
  end
end
