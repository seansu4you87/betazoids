defmodule Betazoids.PageController do
  use Betazoids.Web, :controller

  def index(conn, _params) do
    conn
    |> put_flash(:info, "Welcome to Phoenix, from flash info!")
    |> put_flash(:error, "Let's pretend we have an error.")
    # |> put_layout(false)
    |> render("index.html")
  end
end
