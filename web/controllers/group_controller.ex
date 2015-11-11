defmodule Betazoids.GroupController do
  use Betazoids.Web, :controller

  def index(conn, _params) do
    conn
    |> put_flash(:info, "Welcome to Betazoids bitch")
    |> render("index.html")
  end
end
