defmodule RefData do
  @moduledoc """
  Documentation for `RefData`.
  """

  @doc """
  Returns a list of all key values from the underlying data store.
  It will match the keys used in the individual json files

  ## Examples

      iex> RefData.list_all_keys()
      ["key1", "key2"]

  """
  def list_all_keys() do
    GenServer.call(RefData.Server, {:all_keys})
  end

  @doc """
  Returns a list of values for a given key. The default response
  matches the list required by Phoenix.HTML.select

  OPTIONS:
    :raw - returns a list with a single tuple. The first value
    in the tuple is the key and the second is a list of values
    provided via json. This is the raw data stored in an ets table_name

  ## Examples

      iex> get("gender")
      [
        [key: "Male", value: "male"],
        [key: "Female", value: "female"],
        [key: "Non-binary", value: "non-binary"]
      ]

      iex> get("gender", [])
      [
        [key: "Male", value: "male"],
        [key: "Female", value: "female"],
        [key: "Non-binary", value: "non-binary"]
      ]

      iex> get("gender", [:raw])
      [{"gender", ["Male", "Female", "Non-binary"]}]


  """

  def get(key) do
    GenServer.call(RefData.Server, key)
  end

  def get(key, []), do: get(key)

  def get(key, [:raw]) do
    GenServer.call(RefData.Server, {key, :raw})
  end

  def get(key, disabled: list) do
    GenServer.call(RefData.Server, {key, disabled: list})
  end
end
