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

  import Ecto.Query

  alias Betazoids.CollectorLog
  alias Betazoids.Facebook
  alias Betazoids.Repo

  @betazoids_thread_id "438866379596318"
  # @sean_yu_long_lived_token "CAAMD90ZCeW1YBAE6tBMgPBeNhtbY0nUj6Il1A34dZAOqrSZCxwjsEu1uJjU8VQGrrOUc1DhLvXSfPCcW6ZBBDLsYG6ZAznoSi8l0t4qbKSDUZCSfmIFtDdnQMnGgkSa8DGAGkmpFMZAR4JIvAS4QmNgh2Q6e7VZCE04tWws4JGs2zdWf6taslUgKdCuHNXeEoqEZD"
  @graph_explorer_token "CAACEdEose0cBAGf1yHYpoO2AI81xsKcq093zoVX0dwHpjAmV45A3YSOviPBWAAfoKHNidsnQRL1yi4yaHVK9a2ebU8pqf2pY5P4aZAeWqLYHDjCpYImnJn3pZAMQvFK14oGhwEqHktI6lB8EDbg9BfZAaCopbtDpA3fcdUkKD0hIoYtXtnIgna1GH2SzZBCHjhSjqbuIogZDZD"

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: Betazoids.Collector])
  end

  def init([]) do
    children = [
      worker(Task, [__MODULE__, :collect_thread, []], [name: Betazoids.Collector.ThreadProcessor])
    ]

    supervise(children, strategy: :one_for_one)
  end

  def check_betazoids do
    path = Facebook.thread(@betazoids_thread_id, @graph_explorer_token)
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

  def collect_thread do
    case last_collector_log do
      []                          -> {:ok, collector_log} = fetch_head
      [%CollectorLog{done: true}] -> {:ok, collector_log} = fetch_head
      [last_log]                  -> collector_log = last_log
    end

    {:ok, _} = fetch_next(collector_log)

    collect_thread
  end

  defp fetch_head do
    Repo.transaction fn ->
      {:ok, collector_log} = create_collector_log
      {:ok, res} = check_betazoids

      changeset = CollectorLog.changeset(collector_log, %{
        fetch_count: 1,
        message_count: length(res.comments),
        next_url: res.paging.next
      })
      {:ok, updated_collector_log} = Repo.update(changeset)

      process_comments(res.comments, updated_collector_log)
      updated_collector_log
    end
  end

  defp fetch_next(collector_log, tracer \\ []) do
    IO.puts "********************************************"
    IO.puts "tracer #{inspect tracer}"
    IO.puts "********************************************"
    case collector_log.done do
      false ->
        next_path = path_from_url(collector_log.next_url)
        %HTTPoison.Response{status_code: 200, body: body} = Facebook.get!(next_path)
        comments = body.data

        if length(comments) == 0 do
          # done
          changeset = CollectorLog.changeset(collector_log, %{done: true})
          {:ok, collector_log} = Repo.update(changeset)
        else
          changeset = CollectorLog.changeset(collector_log, %{
            fetch_count: collector_log.fetch_count + 1,
            message_count: collector_log.message_count + length(comments),
            next_url: body.paging.next
          })

          # TODO(yu): This should be inside the transaction but it raises an
          # error for some reason
          {:ok, collector_log} = Repo.update(changeset)
          Repo.transaction fn ->
            process_comments(comments, collector_log)
          end
        end

        IO.puts """
        #{collector_log.fetch_count} -
        total: #{collector_log.message_count},
        add #{length(comments)} comments, first:
        #{List.first(comments).created_time}
        """

        :timer.sleep(1500)
        fetch_next(collector_log, tracer ++ [collector_log.fetch_count])
      true ->
        IO.puts """
        done fetching #{collector_log.message_count} messages
        in #{collector_log.fetch_count} fetches
        """

        {:ok, collector_log}
    end
  end

  defp last_collector_log do
    query = from cl in CollectorLog,
       order_by: [desc: cl.id],
          limit: 1,
         select: cl
    Repo.all(query)
  end

  defp create_collector_log do
    changeset = CollectorLog.changeset(%CollectorLog{}, %{})
    Repo.insert(changeset)
  end

  defp create_facebook_user(%{id: id, name: name}) do
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

  defp create_facebook_message(%{
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

  defp betazoids_member_cache do
    query = from u in Facebook.User,
         select: u

    Repo.all(query)
    |> Enum.reduce %{}, fn(u, cache) -> Map.put(cache, u.facebook_id, u) end
  end

  defp process_comments(comments, collector_log) do
    ids = comments |> Enum.map(fn(c) -> c.id end) |> Enum.sort
    require IEx; IEx.pry
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

  defp path_from_url(url) do
    String.slice(url, 31..-1)
  end

end
