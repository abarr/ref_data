defmodule RefData do
  @moduledoc """
  Loads JSON reference datasets into memory for form options and other lookups.

  Call this module directly or use `use RefData` to define a compatible wrapper.
  See the README for data formats, configuration and supervision examples.
  """

  @type option :: [key: String.t(), value: String.t() | number() | boolean(), disabled: boolean()]
  @type group :: {String.t(), [option() | group()]}
  @type options :: [option() | group()]
  @type lookup_options :: [disabled: [String.t()], server: GenServer.server()]

  @doc "Starts a reference data server. Requires `:path`; accepts `:name` to override the default server name."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: RefData.Server.start_link(opts)

  @doc false
  def child_spec(opts) do
    %{id: Keyword.get(opts, :name) || __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  @doc "Returns the dataset names in alphabetical order."
  @spec list_all_keys(GenServer.server()) :: [String.t()]
  def list_all_keys(server \\ RefData.Server), do: GenServer.call(server, {:get_all_keys})

  @doc "Returns `{:ok, options}` or `:error` when the dataset does not exist."
  @spec fetch(String.t(), lookup_options()) :: {:ok, options()} | :error
  def fetch(key, opts \\ []) when is_binary(key) do
    validate_options!(opts)

    case GenServer.call(Keyword.get(opts, :server, RefData.Server), {:fetch, key}) do
      {:ok, data} -> {:ok, disable_options(data, Keyword.get(opts, :disabled, []))}
      :error -> :error
    end
  end

  @doc """
  Returns the dataset options, or `nil` if the dataset does not exist.

  `:disabled` lists option labels (the `key` fields), including labels in groups.
  `:server` selects a named server or PID. Neither option changes the stored data.
  """
  @spec get(String.t(), lookup_options()) :: options() | nil
  def get(key, opts \\ []) do
    case fetch(key, opts) do
      {:ok, data} -> data
      :error -> nil
    end
  end

  @doc "Returns dataset options, raising `KeyError` if the dataset does not exist."
  @spec get!(String.t(), lookup_options()) :: options()
  def get!(key, opts \\ []) do
    case fetch(key, opts) do
      {:ok, data} -> data
      :error -> raise KeyError, key: key, term: __MODULE__
    end
  end

  @doc false
  def disable_options(data, []), do: data

  def disable_options(data, disabled) do
    disabled = MapSet.new(disabled)
    disable(data, disabled)
  end

  defp disable(data, disabled) do
    Enum.map(data, fn
      {label, values} ->
        {label, disable(values, disabled)}

      [key: key, value: value] = option ->
        if MapSet.member?(disabled, key),
          do: option ++ [disabled: true],
          else: [key: key, value: value]
    end)
  end

  defp validate_options!(opts) do
    unless Keyword.keyword?(opts), do: raise(ArgumentError, "expected keyword options")
    Keyword.validate!(opts, [:disabled, :server])
    disabled = Keyword.get(opts, :disabled, [])

    unless is_list(disabled) and Enum.all?(disabled, &is_binary/1) do
      raise ArgumentError, ":disabled must be a list of option labels"
    end
  end

  @doc "Defines lookup functions delegating to RefData. Accepts a `:server` option."
  defmacro __using__(opts) do
    server = Keyword.get(opts, :server, RefData.Server)

    quote do
      def list_all_keys, do: RefData.list_all_keys(unquote(server))

      def get(key, opts \\ []),
        do: RefData.get(key, Keyword.put_new(opts, :server, unquote(server)))

      def get!(key, opts \\ []),
        do: RefData.get!(key, Keyword.put_new(opts, :server, unquote(server)))

      def fetch(key, opts \\ []),
        do: RefData.fetch(key, Keyword.put_new(opts, :server, unquote(server)))
    end
  end
end
