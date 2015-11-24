defmodule Betazoids.Facebook.AccessToken do
  use Betazoids.Web, :model

  schema "facebook_access_tokens" do
    field :token, :string
    field :type, :string, default: ":short"

    timestamps
  end

  @required_fields ~w(token type)
  @optional_fields ~w()

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
