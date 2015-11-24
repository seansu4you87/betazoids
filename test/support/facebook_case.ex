defmodule Betazoids.FacebookCase do
  @moduledoc """
  This module defines various facebook api responses to be used for testing
  purposes
  """

  use ExUnit.CaseTemplate

  def fb do
    %{
      access_token_expired: access_token_expired
    }
  end

  defp access_token_expired do
    %HTTPoison.Response{
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
end
