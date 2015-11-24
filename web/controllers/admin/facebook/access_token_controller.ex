defmodule Betazoids.Admin.Facebook.AccessTokenController do
  use Betazoids.Web, :controller

  alias Betazoids.Facebook.AccessToken

  plug :scrub_params, "access_token" when action in [:create, :update]

  def index(conn, _params) do
    facebook_access_tokens = Repo.all(AccessToken)
    render(conn, "index.html", facebook_access_tokens: facebook_access_tokens)
  end

  def new(conn, _params) do
    changeset = AccessToken.changeset(%AccessToken{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"access_token" => access_token_params}) do
    changeset = AccessToken.changeset(%AccessToken{}, access_token_params)

    case Repo.insert(changeset) do
      {:ok, _access_token} ->
        conn
        |> put_flash(:info, "Access token created successfully.")
        |> redirect(to: access_token_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    access_token = Repo.get!(AccessToken, id)
    render(conn, "show.html", access_token: access_token)
  end

  def edit(conn, %{"id" => id}) do
    access_token = Repo.get!(AccessToken, id)
    changeset = AccessToken.changeset(access_token)
    render(conn, "edit.html", access_token: access_token, changeset: changeset)
  end

  def update(conn, %{"id" => id, "access_token" => access_token_params}) do
    access_token = Repo.get!(AccessToken, id)
    changeset = AccessToken.changeset(access_token, access_token_params)

    case Repo.update(changeset) do
      {:ok, access_token} ->
        conn
        |> put_flash(:info, "Access token updated successfully.")
        |> redirect(to: access_token_path(conn, :show, access_token))
      {:error, changeset} ->
        render(conn, "edit.html", access_token: access_token, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    access_token = Repo.get!(AccessToken, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(access_token)

    conn
    |> put_flash(:info, "Access token deleted successfully.")
    |> redirect(to: access_token_path(conn, :index))
  end
end
