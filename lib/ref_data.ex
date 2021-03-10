defmodule RefData do
  @moduledoc """
  RefData is a library for Phoenix projects that lets you provide reference data
  for your forms (e.g. Gender) without using a database table. It has been written
  as tool for POC development but can be used in PROD for fields that are common
  and do not form part of complex queries.
  """

  defmacro __using__(_opts) do
    quote do
      def list_all_keys() do
        GenServer.call(RefData.Server, {:get_all_keys})
      end

      def get(key) do
        GenServer.call(RefData.Server, {key})
      end

      def get(key, disabled: list) do
        GenServer.call(RefData.Server, {key, disabled: list})
      end
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
        [key: "Male", value: "Male"],
        [key: "Female", value: "Female"],
        [key: "Non-binary", value: "non-binary"]
      ]

      iex(1)> MyRefData.get("countries")
      [
        Asia: [
          [key: "Australia", value: "Australia"],
          [key: "New Zealand", value: "New Zealand"]
        ],
        Americas: [
          [key: "Canada", value: "Canada"],
          [key: "USA", value: "USA"]]
      ]

  """
  @callback get(key :: String) :: List

  @doc """
  You can pass params to the get function. Keywords available
  - disabled: [] - Will return the data with the listed fields disabled

  ## Example

    iex(1)> MyRefData.get("gender", disabled: ["Female"])
    [
      [key: "Male", value: "Male"],
      [key: "Female", value: "Female", disabled: true],
      [key: "Non-binary", value: "Non-binary"]
    ]

  """
  @callback get(key :: String, {:disabled, []}) :: List
end
