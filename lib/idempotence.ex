defmodule Idempotence do
  import Ecto.Query # , only: [from: 1, from: 2, from: 3]

  def create(repo_mod, model_mod, changeset, unique_key, ignored_keys \\ []) do
    case apply(repo_mod, :insert, [changeset]) do
      {:ok, model} -> {:ok, %{created: true, model: model}}
      {:error, %Ecto.Changeset{errors: [{^unique_key, "has already been taken"}]}} ->
        unique_key_value = changeset.changes[unique_key]
        query = from table in model_mod,
              where: field(table, ^unique_key) == ^unique_key_value,
             select: table
        [model] = apply(repo_mod, :all, [query])
        {:ok, %{created: false, model: model}}
    end
  end
end
