defmodule Betazoids.Facebook.Message do
  use Betazoids.Web, :model

  schema "facebook_messages" do
    field :text, :string
    field :facebook_id, :string
    field :created_at, Ecto.DateTime

    belongs_to :user, Betazoids.Facebook.User
    belongs_to :collector_log, Betazoids.CollectorLog
    field :collector_log_fetch_count, :integer

    timestamps
  end

  @required_fields ~w(facebook_id created_at user_id collector_log_id collector_log_fetch_count)
  @optional_fields ~w(text)

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
