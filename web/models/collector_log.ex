defmodule Betazoids.CollectorLog do
  use Betazoids.Web, :model

  schema "collector_logs" do
    field :message_count, :integer, default: 0
    field :fetch_count, :integer, default: 0
    field :next_url, :string
    field :done, :boolean, default: false

    timestamps
  end

  @required_fields ~w(message_count fetch_count done)
  @optional_fields ~w(next_url)

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
