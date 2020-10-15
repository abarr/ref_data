defmodule RefData.Server do
  use GenServer
  alias RefData.Helpers

  def start_link(arg, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, arg, [name: name])
  end

  def init(arg) do
    table_name = :ets.new(:ref_data, [:named_table, read_concurrency: true])
    Helpers.get_file_paths(arg)
    |> Helpers.load_ref_data()
    {:ok, table_name}
  end

  def handle_call(_ref_data, _from, nil) do
    {:stop, "The Application was unable to load reference data", nil}
  end

  def handle_call({:all_keys}, _from, table_name) do
    {:reply, Enum.into(:ets.tab2list(table_name), [], fn {k, _v} -> k end), table_name}
  end

  def handle_call({key, :raw}, _from, table_name) do
    {:reply, :ets.lookup(table_name, key), table_name}
  end

  def handle_call({key, disabled: disabled_list}, _from, table_name) do
    disabled_list = Helpers.capitalise_list(disabled_list)

    case :ets.lookup(table_name, key) do
      [{_key, value}] ->
        list =
          Enum.into(value, [], fn v -> {v, String.downcase(v)} end)
          |> Enum.into([], fn {k, v} ->
            case Enum.member?(disabled_list, k) do
              true -> [key: k, value: v, disabled: true]
              _ -> [key: k, value: v]
            end
          end)

        {:reply, list, table_name}

      _ ->
        {:error, "Key: #{key} does not exist"}
    end
  end

  def handle_call(key, _from, table_name) do
    value = :ets.lookup(table_name, key)

    case Helpers.is_grouped?(value) do
      true ->
        cond do
          !Helpers.single_level?(value) ->
            {:error, "Incorrect format for #{key}"}

          true ->
            [{_key, list}] = value
            {:reply, Helpers.return_grouped_values(list, []), table_name}
        end

      _ ->
        {:reply, Helpers.return_values(value), table_name}
    end
  end
end
