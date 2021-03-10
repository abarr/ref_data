defmodule RefData.Data do
  @moduledoc false

  # Take a directory path and standardise a list of file paths
  # for json file types
  def get_file_paths(dir) do
    list =
      "#{dir}/*.json"
      |> Path.wildcard()
      |> Enum.sort()

    if is_list(list) do
      {:ok, list}
    else
      {:error, "Unable to get list of file paths"}
    end
  end

  # Takes a list of file paths and standardises a list of maps
  # Each map represents a set of defined reference data
  def load_ref_data([]), do: {:error, "Cannot load json files, must be a list of strings"}

  def load_ref_data(paths) when is_list(paths) do
    paths
    |> Enum.map(fn path ->
      path
      |> read_file()
      |> Jason.decode!(strings: :copy)
    end)
    |> standardise([], :valid)
  end

  def load_ref_data(_), do: {:error, "Must provide a list of paths to load reference data"}

  defp standardise(_, _, :invalid), do: {:error, "Unable to parse json files"}

  defp standardise([], standardised_list, :valid), do: {:ok, standardised_list}

  defp standardise([map | rest], standardised_list, :valid) do
    map = standardise(map)
    standardise(rest, [map | standardised_list], :valid)
  end

  # Capture key and data values when defined in JSON
  defp standardise(%{"name" => name, "data" => data}), do: standardise(name, data)

  # Capture key and data values when JSON is simple definition
  defp standardise(%{} = map) do
    [name] = Map.keys(map)
    data = Map.get(map, name)
    standardise(name, data)
  end

  # Creates a standard list of maps for GenServer State
  defp standardise(name, data) when is_binary(name) and is_list(data) do
    data = standardise_values(data)
    %{name: name, data: data}
  end

  # Standardise when JSON definition includes keys
  defp standardise_values([%{"key" => _key, "value" => _value} | _t] = values) do
    Enum.into(values, [], fn %{"key" => key, "value" => value} -> [key: key, value: value] end)
  end

  # Standardise when JSON definition is simple list and value is both key and value
  defp standardise_values([h | _t] = values) when is_binary(h) do
    Enum.into(values, [], fn v -> {v, v} end)
    |> Enum.into([], fn {k, v} -> [key: k, value: v] end)
  end

  # Standardise when JSON definition is a grouped data
  defp standardise_values([h | _t] = values) when is_map(h) do
    Enum.into(values, [], fn map ->
      [key] = Map.keys(map)
      data = Map.fetch!(map, key)
      standardised_data = standardise_values(data)
      ["#{key}": standardised_data]
    end)
  end

  defp read_file(path) when is_binary(path), do: File.read!(path)

  defp read_file(_), do: {:error, "Cannot load json files, path is not a valid binary"}
end
