defmodule Idempotence do
  defmodule DifferentValuesError do
    defexception message: "Not idempotent, different values"
  end

  import Ecto.Query

  @doc """
  Creates idempotently, based on a `unique_key` and `changeset`.

  `opts` contains special options:
  * `:before_callback` a function to execute before the model is created, not called if creation is not idempotent
  * `:after_callback` a function to execute after the model is created, not called if creation is not idempotent
  """
  def create(repo_mod, model_mod, unique_key, changeset, opts \\ []) do
    before_callback = opts[:before_callback]
    after_callback = opts[:after_callback]
    transaction_fun = fn ->
      if before_callback != nil, do: before_callback.()
      res = case apply(repo_mod, :insert, [changeset]) do
        {:ok, model} ->
          if after_callback != nil, do: after_callback.()
          model
        {:error, changeset} -> apply(repo_mod, :rollback, [changeset])
      end
    end

    case apply(repo_mod, :transaction, [transaction_fun]) do
      {:ok, model} -> {:ok, %{created: true, model: model}}
      {:error, %Ecto.Changeset{errors: [{^unique_key, "has already been taken"}]}} ->
        [model] = query_model(repo_mod, model_mod, unique_key, changeset.changes[unique_key])
        case idempotent?(model, changeset) do
          true ->
            if before_callback != nil, do: before_callback.()
            if after_callback != nil, do: after_callback.()
            {:ok, %{created: false, model: model}}
          {false, diffs} -> raise_on_different_values(diffs)
        end
    end
  end

  defp raise_on_different_values(diffs) do
    message = diffs
    |> Enum.reduce("Different Values: ", fn({k, v}, m ) ->
      m <> "#{k}: #{inspect elem(v, 0)} != #{inspect elem(v, 1)}"
    end)
    raise DifferentValuesError, message: message
  end

  defp query_model(repo_mod, model_mod, unique_key, unique_key_value) do
    query = from table in model_mod,
          where: field(table, ^unique_key) == ^unique_key_value,
         select: table
    apply(repo_mod, :all, [query])
  end

  defp idempotent?(model, changeset) do
    diffs = differences(model, changeset)
    if map_size(diffs) == 0 do
      true
    else
      {false, diffs}
    end
  end

  defp differences(model, changeset) do
    changeset.changes
    |> Enum.reduce(%{}, fn({k,v}, diffs) ->
      model_value = Map.get(model, k)
      if v != model_value, do: diffs = Map.put(diffs, k, {model_value, v})
      diffs
    end)
  end
end
