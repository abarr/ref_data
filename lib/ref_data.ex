defmodule RefData do
  @moduledoc """
  RefData is a library for Phoenix projects that lets you provide reference data
  for your forms (e.g. Gender) without using a database table. It has been written
  as tool for POC development but can be used in PROD for fields that are common
  for all Users and do not form part of complex queries.
  """

  defmacro __using__(_opts) do
    quote do
      def list_all_keys() do
        GenServer.call(RefData.Server, {:all_keys})
      end

      def get(key) do
        GenServer.call(RefData.Server, key)
      end

      def get(key, :raw) do
        GenServer.call(RefData.Server, {key, :raw})
      end

      def get(key, disabled: list) do
        GenServer.call(RefData.Server, {key, disabled: list})
      end

      def get(key, _), do: get(key)
    end
  end

  @doc """
  Returns a list of all key values from the underlying data store.
  It will match the keys used in the individual json files

  ## Examples

      iex> RefData.list_all_keys()
      ["key1", "key2"]

  """
  @callback list_all_keys() :: List

  @doc """
  Returns a list of data for the provided key. If the json defines
  grouped data it will return grouped data.

  ## Examples

      iex(1)> MyRefData.get("gender")
      [
        [key: "Male", value: "male"],
        [key: "Female", value: "female"],
        [key: "Non-binary", value: "non-binary"]
      ]

      iex(1)> MyRefData.get("countries")
      [
        Asia: [
          [key: "Australia", value: "australia"],
          [key: "New Zealand", value: "new zealand"]
        ],
        Americas: [
          [key: "Canada", value: "canada"],
          [key: "USA", value: "usa"]]
      ]

  """
  @callback get(key :: String) :: List

  @doc """
  You can pass params to the get function. Keywords available
  - :raw - Will return the raw data stored by RefData
  - disabled: [] - Will return the data with the listed fields disabled

  ## Examples

    iex(1)> MyRefData.get( "gender", :raw)
    [
      {
        "gender": ["Male", "Female", "Non-binary"]
      }
    ]

    iex(1)> MyRefData.get("gender", disabled: ["Female"])
    [
      [key: "Male", value: "male"],
      [key: "Female", value: "female", disabled: true],
      [key: "Non-binary", value: "non-binary"]
    ]

  """
  @callback get(key :: String, :raw) :: List
  @callback get(key :: String, {:disabled, []}) :: List
end
