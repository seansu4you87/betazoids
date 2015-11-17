defmodule Betazoids.Facebook.User do
  use Betazoids.Web, :model

  schema "facebook_users" do
    field :name, :string
    field :facebook_id, :string

    has_many :messages, Betazoids.Facebook.Message

    timestamps
  end

  @required_fields ~w(name facebook_id)
  @optional_fields ~w()

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:facebook_id)
  end
end
