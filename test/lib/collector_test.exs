defmodule Betazoids.CollectorTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  alias Betazoids.Collector
  alias Betazoids.Facebook
  alias Betazoids.Repo

  setup tags do
    Ecto.Adapters.SQL.restart_test_transaction(Betazoids.Repo, [])
    :ok
  end

  test "#create_facebook_message" do
    raw_user = %{
      name: "Ben Cunningham",
      id: "12"
    }
    Collector.create_facebook_user(raw_user)

    raw_message = %{
      id: "101",
      from: raw_user,
      message: "I'm gonna KYS",
      created_time: "2015-11-17T02:51:30+0000"
    }

    assert elem(Collector.create_facebook_message(raw_message), 0) == :ok

    query = from m in Facebook.Message,
         select: m
    assert length(Repo.all(query)) == 1
  end

  test "#create_facebook_message with cache" do
    raw_user = %{
      name: "Nick Wilde",
      id: "13"
    }
    {:ok, nick} = Collector.create_facebook_user(raw_user)
    cache = %{"13" => nick}

    raw_message = %{
      id: "102",
      from: raw_user,
      message: "WHAT ABOUT SQL, PATHETIC, LOL!",
      created_time: "2015-11-17T02:51:30+0000"
    }

    assert elem(Collector.create_facebook_message(raw_message, cache), 0) == :ok

    query = from m in Facebook.Message,
         select: m
    assert length(Repo.all(query)) == 1
  end
end
