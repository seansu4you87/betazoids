defmodule Betazoids.Router do
  use Betazoids.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Betazoids do
    pipe_through :browser # Use the default browser stack

    get "/", GroupController, :index
    get "/hello", HelloController, :index
    get "/hello/:messenger/", HelloController, :show

    resources "/users", UserController
  end

  scope "/admin", Betazoids do
    pipe_through :browser

    resources "/facebook/access_tokens", Admin.Facebook.AccessTokenController
  end

  # Other scopes may use custom stacks.
  # scope "/api", Betazoids do
  #   pipe_through :api
  # end
end
