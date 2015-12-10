defmodule Betazoids.FacebookCase do
  @moduledoc """
  This module defines various facebook api responses to be used for testing
  purposes
  """

  use ExUnit.CaseTemplate

  alias Betazoids.Collector
  alias Betazoids.Facebook

  using do
    quote do
      use Pavlov.Case, async: false
      import Pavlov.Syntax.Expect

      import Betazoids.FacebookCase
      import Ecto.Query

      alias Betazoids.Collector
      alias Betazoids.CollectorLog
      alias Betazoids.Facebook
      alias Betazoids.FacebookCase
      alias Betazoids.Repo
    end
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

  def make_message_changeset(user, collector_log) do
    Facebook.Message.changeset(%Facebook.Message{}, %{
      facebook_id: "12",
      user_id: user.id,
      text: "EAT SOME CARBS",
      created_at: Ecto.DateTime.utc,
      collector_log_id: collector_log.id,
      collector_log_fetch_count: 25,
    })
  end

  @fb %{
    access_token_expired: @access_token_expired
  }

  @access_token_expired %HTTPoison.Response{
    body: %{
      error: %{
        code: 190,
        error_subcode: 463,
        fbtrace_id: "DXzRWXB0O5d",
        message: "Error validating access token: Session has expired on Monday,
        23-Nov-15 14:00:00 PST. The current time is Monday, 23-Nov-15 14:00:03 PST.",
        type: "OAuthException"
      }
    },
    headers: [
      {"WWW-Authenticate", "OAuth \"Facebook Platform\" \"invalid_token\" \"Error validating access token: Session has expired on Monday, 23-Nov-15 14:00:00 PST. The current time is Monday, 23-Nov-15 14:00:03 PST.\""},
      {"Access-Control-Allow-Origin", "*"},
      {"Content-Type", "text/javascript; charset=UTF-8"},
      {"X-FB-Trace-ID", "DXzRWXB0O5d"},
      {"X-FB-Rev", "2057567"},
      {"Pragma", "no-cache"},
      {"Cache-Control", "no-store"},
      {"Expires", "Sat, 01 Jan 2000 00:00:00 GMT"},
      {"X-FB-Debug", "bvVFZ2UEFLganYUfJzuSBmy+vfuVOTCx7Uy5W6vNUtKdwSrLW5LTTq3KnSBJTMV8EV3VGxzrdQQ8UNlaXCDUjA=="},
      {"Date", "Mon, 23 Nov 2015 22:00:03 GMT"},
      {"Connection", "keep-alive"},
      {"Content-Length", "243"}
    ],
    status_code: 400
  }
end
