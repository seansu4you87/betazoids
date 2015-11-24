defmodule Betazoids.Admin.Facebook.AccessTokenControllerTest do
  use Betazoids.ConnCase

  alias Betazoids.Facebook.AccessToken
  @valid_attrs %{token: "some content", type: "some content"}
  @invalid_attrs %{token: nil}

  setup do
    conn = conn()
    {:ok, conn: conn}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, access_token_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing facebook access tokens"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, access_token_path(conn, :new)
    assert html_response(conn, 200) =~ "New access token"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, access_token_path(conn, :create), access_token: @valid_attrs
    assert redirected_to(conn) == access_token_path(conn, :index)
    assert Repo.get_by(AccessToken, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, access_token_path(conn, :create), access_token: @invalid_attrs
    assert html_response(conn, 200) =~ "New access token"
  end

  test "shows chosen resource", %{conn: conn} do
    access_token = Repo.insert! %AccessToken{token: "blah"}
    conn = get conn, access_token_path(conn, :show, access_token)
    assert html_response(conn, 200) =~ "Show access token"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn ->
      get conn, access_token_path(conn, :show, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    access_token = Repo.insert! %AccessToken{token: "blah"}
    conn = get conn, access_token_path(conn, :edit, access_token)
    assert html_response(conn, 200) =~ "Edit access token"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    access_token = Repo.insert! %AccessToken{token: "blah"}
    conn = put conn, access_token_path(conn, :update, access_token), access_token: @valid_attrs
    assert redirected_to(conn) == access_token_path(conn, :show, access_token)
    assert Repo.get_by(AccessToken, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    access_token = Repo.insert! %AccessToken{token: "blah"}
    conn = put conn, access_token_path(conn, :update, access_token), access_token: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit access token"
  end

  test "deletes chosen resource", %{conn: conn} do
    access_token = Repo.insert! %AccessToken{token: "blah"}
    conn = delete conn, access_token_path(conn, :delete, access_token)
    assert redirected_to(conn) == access_token_path(conn, :index)
    refute Repo.get(AccessToken, access_token.id)
  end
end
