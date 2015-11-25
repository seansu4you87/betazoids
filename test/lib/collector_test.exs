defmodule Betazoids.CollectorTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  alias Betazoids.Collector
  alias Betazoids.CollectorLog
  alias Betazoids.Facebook
  alias Betazoids.Repo

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Betazoids.Repo, [])
    :ok
  end

  def make_comment(fb_id, raw_user, message) do
    %{
      id: to_string(fb_id),
      from: raw_user,
      message: message,
      created_time: datetime_example
    }
  end

  def datetime_example, do: "2015-11-23T18:57:01+0000"

  def raw_chris,   do: %{id: "11", name: "Chris Vaccarino"}
  def raw_ben,     do: %{id: "12", name: "Ben Cunningham"}
  def raw_nick,    do: %{id: "13", name: "Nick Wilde"}
  def raw_matt,    do: %{id: "14", name: "Matt Groff"}
  def raw_daniel,  do: %{id: "15", name: "Daniel Gold"}
  def raw_sean,    do: %{id: "16", name: "Sean Yu"}

  def make_chris,  do: Collector.create_facebook_user(raw_chris)
  def make_ben,    do: Collector.create_facebook_user(raw_ben)
  def make_nick,   do: Collector.create_facebook_user(raw_nick)
  def make_matt,   do: Collector.create_facebook_user(raw_matt)
  def make_daniel, do: Collector.create_facebook_user(raw_daniel)
  def make_sean,   do: Collector.create_facebook_user(raw_sean)

  def make_betazoids do
    {:ok, ben} = make_ben
    {:ok, nick} = make_nick
    {:ok, daniel} = make_daniel
    {:ok, chris} = make_chris
    {:ok, matt} = make_matt
    {:ok, sean} = make_sean

    [ben, nick, daniel, chris, matt, sean]
  end

  test "#process_head" do
    make_chris

    comments = 1..25 |> Enum.map fn(i) -> make_comment(i, raw_chris, "Shut up Daniel") end
    next_url = "http://kys.com"

    Collector.process_head(comments, next_url)

    query = from cl in CollectorLog,
         select: cl
    cls = Repo.all(query)
    assert length(cls) == 1

    [cl] = cls
    assert cl.next_url == next_url
    assert cl.fetch_count == 1
    assert cl.message_count == 25

    query = from m in Facebook.Message,
         select: m
    assert length(Repo.all(query)) == 25
  end

  test "#process_head rollback transaction when there are errors" do
    make_chris

    comments = 1..25 |> Enum.map fn(i) -> make_comment(i, raw_chris, "AGBW on Ellen!") end
    next_url = "http://kys.com"

    # Already created one of the comments
    {:ok, previous_collector_log} = Collector.create_collector_log
    Collector.create_facebook_message(List.last(comments), previous_collector_log)

    assert_raise MatchError, fn -> Collector.process_head(comments, next_url) end

    query = from cl in CollectorLog,
         select: cl
    cls = Repo.all(query)
    assert length(cls) == 1

    [cl] = cls
    assert cl.next_url == nil
    assert cl.fetch_count == 0
    assert cl.message_count == 0

    query = from m in Facebook.Message,
         select: m
    assert length(Repo.all(query)) == 1
  end

  test "#process_done" do
    {:ok, collector_log} = Collector.create_collector_log
    Collector.process_done(collector_log)

    query = from cl in CollectorLog,
         select: cl
    [cl] = Repo.all(query)
    assert cl.done == true
  end

  test "#process_next" do
    make_matt
    {:ok, collector_log} = Repo.insert(CollectorLog.changeset(%CollectorLog{}, %{
      fetch_count: 5,
      message_count: 25,
      next_url: "https://buku.com"
    }))
    comments = 1..25 |> Enum.map fn(i) -> make_comment(i, raw_matt, "beach with Tina on Saturday") end
    next_url = "https://kys.com"

    {:ok, collector_log} = Collector.process_next(collector_log, comments, next_url)
    assert collector_log.fetch_count == 6
    assert collector_log.message_count == 50
    assert collector_log.next_url == next_url

    query = from cl in CollectorLog,
         select: cl
    [cl] = Repo.all(query)

    assert cl.fetch_count == 6
    assert cl.message_count == 50
    assert cl.next_url == next_url

    query = from m in Facebook.Message,
         select: m
    assert length(Repo.all(query)) == 25
  end

  test "#process_next rollback transaction when there are errors" do
    make_matt
    {:ok, collector_log} = Repo.insert(CollectorLog.changeset(%CollectorLog{}, %{
      fetch_count: 5,
      message_count: 25,
      next_url: "https://buku.com"
    }))
    comments = 1..25 |> Enum.map fn(i) -> make_comment(i, raw_matt, "beach with Tina on Saturday") end
    next_url = "https://kys.com"

    # Already created one of the comments
    Collector.create_facebook_message(List.last(comments), collector_log)

    assert_raise MatchError, fn ->
      Collector.process_next(collector_log, comments, next_url)
    end

    query = from cl in CollectorLog,
         select: cl
    [cl] = Repo.all(query)

    assert cl.fetch_count == 5
    assert cl.message_count == 25
    assert cl.next_url == "https://buku.com"

    query = from m in Facebook.Message,
         select: m
    assert length(Repo.all(query)) == 1
  end

  test "#last_collector_log" do
    {:ok, first} = Collector.create_collector_log
    {:ok, second} = Collector.create_collector_log
    {:ok, third} = Collector.create_collector_log

    [last] = Collector.last_collector_log
    assert third == last
  end

  test "create_facebook_user" do
    {:ok, daniel} = Collector.create_facebook_user(raw_daniel)

    query = from u in Facebook.User,
         select: u
    [dan] = Repo.all(query)

    assert dan.facebook_id == raw_daniel.id
    assert dan.name == raw_daniel.name
  end

  test "#create_facebook_message" do
    make_ben
    {:ok, collector_log} = Repo.insert(CollectorLog.changeset(%CollectorLog{}, %{}))

    raw_message = %{
      id: "101",
      from: raw_ben,
      message: "I'm gonna KYS",
      created_time: "2015-11-17T02:51:30+0000"
    }

    assert elem(Collector.create_facebook_message(raw_message, collector_log), 0) == :ok

    query = from m in Facebook.Message,
         select: m
    ms = Repo.all(query)
    assert length(ms) == 1

    [m] = ms
    assert m.facebook_id == "101"
    assert m.text == "I'm gonna KYS"
    assert Ecto.DateTime.to_iso8601(m.created_at) == "2015-11-17T02:51:30Z"
  end

  test "#create_facebook_message with cache" do
    {:ok, nick} = make_nick
    cache = %{"13" => nick}
    {:ok, collector_log} = Repo.insert(CollectorLog.changeset(%CollectorLog{}, %{}))

    raw_message = %{
      id: "102",
      from: raw_nick,
      message: "WHAT ABOUT SQL, PATHETIC, LOL!",
      created_time: "2015-11-17T02:51:30+0000"
    }

    assert elem(Collector.create_facebook_message(raw_message, collector_log, cache), 0) == :ok

    query = from m in Facebook.Message,
         select: m
    assert length(Repo.all(query)) == 1
  end

  test "#betazoids_member_cache" do
    cache = make_betazoids
    |> Enum.reduce %{}, fn(beta, cache) -> Map.put(cache, beta.facebook_id, beta) end
    assert cache == Collector.betazoids_member_cache
  end

  test "#process_comments" do
    make_daniel
    good_comments = 1..24 |> Enum.map fn(i) ->
      make_comment(i, raw_daniel, "God I can't wait to rip gym, SHLEYLAH")
    end

    # DETAIL(yu): the raw comments needs a `:message` field, which our code
    # will insert
    gif_comment = %{id: "25", from: raw_daniel, created_time: datetime_example}
    comments = good_comments ++ [gif_comment]

    {:ok, collector_log} = Collector.create_collector_log

    Collector.process_comments(comments, collector_log)

    query = from m in Facebook.Message,
         select: m
    assert length(Repo.all(query)) == 25
  end

  test "#path_from_url" do
    url = "https://graph.facebook.com/v2.3/438866379596318/comments?limit=25&__paging_token=enc_AdC8PPuPmZCx9JakAa1QJiiZAj7vo1cSe8HO8vxZB1ZAsEyiTYtPmPA6lnW4xgb7gfXH2nJEVk1rig1mnYiWZAAKn2ZA3S&access_token=CAACEdEose0cBAD26EhdO6oyfAsP3nCQVRXWrWqJx6pjJm2aHPPvGPz4Hw0hFixwcip979wvoVpOejppoFf5ZBkWgjlHRkpzNlpVy65oGX55gBegGgqZCJIod6LxZB7Raq8r1dJrn2FwyzEYuVpWe9w46BHL94ZAJwPzJSVH16CsZB96uaIJZAK5kWWckjLqjgEvZBVQeRIGxwZDZD&until=1448233427"

    path = Collector.path_from_url(url)

    assert path == "/438866379596318/comments?limit=25&__paging_token=enc_AdC8PPuPmZCx9JakAa1QJiiZAj7vo1cSe8HO8vxZB1ZAsEyiTYtPmPA6lnW4xgb7gfXH2nJEVk1rig1mnYiWZAAKn2ZA3S&access_token=CAACEdEose0cBAD26EhdO6oyfAsP3nCQVRXWrWqJx6pjJm2aHPPvGPz4Hw0hFixwcip979wvoVpOejppoFf5ZBkWgjlHRkpzNlpVy65oGX55gBegGgqZCJIod6LxZB7Raq8r1dJrn2FwyzEYuVpWe9w46BHL94ZAJwPzJSVH16CsZB96uaIJZAK5kWWckjLqjgEvZBVQeRIGxwZDZD&until=1448233427"
  end

  test "#parse_date" do
    # def datetime_example, do: "2015-11-23T18:57:01+0000"

    {:ok, date} = Collector.parse_date(datetime_example)

    assert date.__struct__ == Ecto.DateTime
    assert date.year == 2015
    assert date.month == 11
    assert date.day == 23
    assert date.hour == 18
    assert date.min == 57
    assert date.sec == 01
    assert date.usec == 0
  end

  test "#graph_explorer_access_token" do
    {:ok, first} = Repo.insert Facebook.AccessToken.changeset(%Facebook.AccessToken{}, %{token: "blah"})
    {:ok, second} = Repo.insert Facebook.AccessToken.changeset(%Facebook.AccessToken{}, %{token: "blah blah"})

    assert Collector.graph_explorer_access_token == second.token
  end

  test "#reauth_url" do
    {:ok, token} = Repo.insert Facebook.AccessToken.changeset(%Facebook.AccessToken{}, %{token: "blah"})

    url = "https://graph.facebook.com/v2.3/438866379596318/comments?limit=25&__paging_token=enc_AdC8PPuPmZCx9JakAa1QJiiZAj7vo1cSe8HO8vxZB1ZAsEyiTYtPmPA6lnW4xgb7gfXH2nJEVk1rig1mnYiWZAAKn2ZA3S&access_token=CAACEdEose0cBAD26EhdO6oyfAsP3nCQVRXWrWqJx6pjJm2aHPPvGPz4Hw0hFixwcip979wvoVpOejppoFf5ZBkWgjlHRkpzNlpVy65oGX55gBegGgqZCJIod6LxZB7Raq8r1dJrn2FwyzEYuVpWe9w46BHL94ZAJwPzJSVH16CsZB96uaIJZAK5kWWckjLqjgEvZBVQeRIGxwZDZD&until=1448233427"

    url = Collector.reauth_url(url)

    assert url == "https://graph.facebook.com/v2.3/438866379596318/comments?limit=25&__paging_token=enc_AdC8PPuPmZCx9JakAa1QJiiZAj7vo1cSe8HO8vxZB1ZAsEyiTYtPmPA6lnW4xgb7gfXH2nJEVk1rig1mnYiWZAAKn2ZA3S&access_token=blah&until=1448233427"
    end
end
