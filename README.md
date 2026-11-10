# RefData

[![Elixir CI](https://github.com/abarr/ref_data/actions/workflows/elixir.yml/badge.svg)](https://github.com/abarr/ref_data/actions/workflows/elixir.yml)

RefData loads JSON reference datasets into memory for form options and other lookups,
without a database. It uses Elixir's built-in `JSON` module and has no runtime dependencies.
Once a path is configured, RefData loads datasets into shared ETS storage at application
startup. Lookups read directly from ETS, and the same datasets validate submitted form
values and supply labels for stored values.
Standalone immutable catalogs are also available when you want to load and pass data
explicitly.

## Requirements and installation

Elixir 1.18 or later and a compatible Erlang/OTP version are required. Development is
pinned to Elixir 1.20.5 and OTP 29.1.2 in `.tool-versions`.

```elixir
def deps do
  [{:ref_data, "~> 0.3.0"}]
end
```

## Choosing how to store data

**Use shared ETS storage for a Phoenix app or any application where several parts
need the same datasets.** Controllers, LiveViews and background jobs can look up
options by name without receiving a catalog as an argument. This is the default:
`RefData.get("countries")` and `RefData.validate_value("countries", value)` use ETS.

**Use a standalone catalog for a script, an isolated job, a test, or a function that
should receive its reference data explicitly.** Load a snapshot and pass it to the
functions that need it using `source: catalog`.

| | Shared ETS storage (default) | Standalone catalog |
| --- | --- | --- |
| Best fit | Reference data used throughout an application | Self-contained tasks and explicit data passing |
| Where data lives | An ETS table shared by callers on one node | An immutable Elixir map held by the caller |
| Loading | Automatically at startup, or through an explicitly supervised instance | When you call `RefData.load/1` |
| Reading | Direct ETS reads, without lookup messages to the owner | Ordinary function calls using the supplied catalog |
| Lifecycle | A supervised GenServer owns the table and reloads it after a crash | The caller holds the snapshot; no dataset server is required |
| Loading changed files | Restart the storage instance | Load a new catalog |

Both options parse JSON when loading and keep the data in memory for subsequent
lookups. Both use the same data formats, grouping, disabled-option handling and
submitted-value validation. Choose based on how you want to share and manage the
data; a standalone catalog does not replace the shared default implicitly.

## Shared ETS storage (default)

Tell RefData where your datasets are and it starts a supervised owner that loads the
`*.json` files in that directory into ETS. Put them in your application's
`priv/ref_data/` directory so Mix bundles them into releases. To create the directory
with an example dataset, run:

```sh
mix ref_data.init
```

Then resolve the path at runtime in `config/runtime.exs`:

```elixir
import Config

config :ref_data,
  path: Application.app_dir(:my_app, "priv/ref_data")
```

The GenServer manages loading and table ownership; local reads bypass its mailbox.
You do not need to call `RefData.load/1` or pass a `:source` option for this workflow.

An empty directory is valid; a missing directory or invalid file stops startup with
an error identifying the path. Without a configured `:path` no default server is
started, and lookups that do not name a `:source` or `:server` exit with `:noproc`.

Datasets are trusted input: files are read whole, with no size limits. Point RefData
only at directories your application controls, never at user-uploaded files.

### Supervising it yourself

Alternatively, leave `:path` unset and add an instance to your application's
supervision tree:

```elixir
children = [
  {RefData, name: MyApp.ReferenceData, path: Application.app_dir(:my_app, "priv/ref_data")}
]
```

Query it with `RefData.get("countries", server: MyApp.ReferenceData)`. Instances have
independent data. Use different names for multiple instances, or `name: nil` for an
unnamed process and query it by PID. Data is loaded at startup; restart an instance
to load changed files. Local lookups read directly from a protected ETS table;
they do not send requests to the storage server. The server owns the table and
loads its contents before publishing it to readers. Stopping the server deletes
the table. Reads by name resolve the current instance after a restart. Reads during
shutdown or startup can exit with `:noproc`; this is distinct from a missing dataset.
Remote server lookups retain message-based access because ETS is local to a node.

## Standalone catalogs (opt-in)

Choose this option when you want to hold a snapshot explicitly, such as inside a
script or an isolated job. No configuration is needed. Load a directory once and
pass the returned immutable snapshot to ordinary functions:

```elixir
{:ok, catalog} = RefData.load("priv/ref_data")

RefData.list_all_keys(catalog)
RefData.get("countries", source: catalog)
RefData.validate_value("countries", "Australia", source: catalog)
```

Loading and querying a catalog does not require a server, a Registry or an ETS table.
A catalog keeps its original data even if the files change; call `RefData.load/1`
again to obtain a new snapshot. Calling `RefData.load/1` does not populate or switch
the shared ETS storage: pass `source: catalog` for each catalog lookup or validation.
You can also use catalogs alongside the shared ETS storage.

Lookup and validation functions accept either `source: catalog`, `source: server`
or the existing `server: server` option. Do not supply both `:source` and `:server`.
`RefData.load/1` returns `{:error, reason}` for invalid files, just like server startup.

## Data formats

Each file defines one dataset. Names must be unique across the directory. Files are
loaded alphabetically; option order within each dataset is preserved.

A simple dataset:

```json
{"countries": ["Australia", "New Zealand", "Canada"]}
```

An explicit dataset with separate labels (`key`) and submitted values (`value`):

```json
{
  "name": "status",
  "data": [
    {"key": "Enabled", "value": true},
    {"key": "Disabled", "value": false}
  ]
}
```

Labels must be strings. Explicit values may be strings, numbers or booleans and
retain their JSON types: `"true"` remains a string, while `true` is a boolean.
Empty datasets and empty groups are supported.

Groups use a string label and a list of options. Groups may contain either simple
strings or explicit key/value entries, and may be nested:

```json
{
  "countries_grouped": [
    {"Oceania": ["Australia", "New Zealand"]},
    {"Americas": [{"key": "Canada", "value": "CA"}]}
  ]
}
```

Group labels remain strings; no atoms are created from JSON labels.

## Lookups

With the default shared ETS storage:

```elixir
RefData.list_all_keys()
# => ["countries", "countries_grouped", "status"]

RefData.get("countries")
# => [[key: "Australia", value: "Australia"],
#     [key: "New Zealand", value: "New Zealand"],
#     [key: "Canada", value: "Canada"]]

RefData.get("countries_grouped")
# => [{"Oceania", [[key: "Australia", value: "Australia"],
#                   [key: "New Zealand", value: "New Zealand"]]},
#     {"Americas", [[key: "Canada", value: "CA"]]}]

RefData.fetch("missing")
# => :error

RefData.get("missing")
# => nil

RefData.get!("missing")
# raises KeyError in the caller; the server continues running
```

Disable options by **label**, including labels inside groups:

```elixir
RefData.get("countries", disabled: ["Canada"])
# => [[key: "Australia", value: "Australia"],
#     [key: "New Zealand", value: "New Zealand"],
#     [key: "Canada", value: "Canada", disabled: true]]
```

These results can be passed to `Phoenix.HTML.Form.options_for_select/2`.
Disabling options only changes the returned result, not the stored dataset.

Existing wrapper modules remain supported:

```elixir
defmodule MyApp.MyRefData do
  use RefData
end

# Or configure a supervised instance:
defmodule MyApp.CustomRefData do
  use RefData, server: MyApp.ReferenceData
end
```

Both wrappers expose `list_all_keys/0`, `get/1,2`, `fetch/1,2`, `get!/1,2`,
`label/2,3`, `validate_value/2,3` and `valid_value?/2,3`. Pass `source: catalog` to override a
wrapper's server for a particular lookup or validation.

## Displaying stored values

`label/3` returns the label for a value you saved earlier, searching groups too:

```elixir
RefData.label("countries_grouped", "CA")
# => "Canada"

RefData.label("status", true)
# => "Enabled"

RefData.label("status", "unknown")
# => nil
```

It returns `nil` for an unknown dataset or value. A value of the same type is
preferred; otherwise a string matches a value's string representation, so `"true"`
finds the label for `true`. If several labels share a value, the first is returned.
Disabled options are not considered: a stored value keeps its label.

## Validating submitted values

`validate_value/3` checks a single submitted value against the dataset's **values**,
including options nested inside groups. It returns the canonical value for an
allowed choice. Labels are not accepted unless they are also a stored value.

For the `status` dataset above:

```elixir
RefData.validate_value("status", "true")
# => {:ok, true}

RefData.validate_value("status", "false")
# => {:ok, false}

RefData.validate_value("status", "Enabled")
# => {:error, :invalid_value}

RefData.validate_value("status", "true", disabled: ["Enabled"])
# => {:error, :disabled_value}

RefData.valid_value?("status", "false")
# => true
```

Browser form fields arrive as strings. A string must exactly equal the string
representation of a known value: `"1"` can match the integer `1`, but `"01"`,
`"1.0"` and `" 1"` do not. Numeric and boolean inputs must match their stored types
exactly. Nulls, lists and maps are invalid single values. Validate each choice
separately for a multi-select field.

Pass the same disabled labels when rendering options and validating submissions.
Rendering with `disabled:` does not change the shared data or establish a permanent
validation rule. If several labels share a value, it remains valid when at least
one matching label is enabled.

A string that matches distinct enabled values, such as JSON `true` and `"true"`,
returns `{:error, :ambiguous_value}`. Choose unambiguous codes for form fields.
An unknown dataset returns `{:error, :unknown_dataset}`. `valid_value?/3` returns
`false` for any validation error, while unavailable shared storage still exits.

A typical form handler can use the returned canonical value:

```elixir
case RefData.validate_value("status", params["status"], disabled: disabled_labels) do
  {:ok, value} -> {:ok, Map.put(params, "status", value)}
  {:error, reason} -> {:error, {:status, reason}}
end
```

## Migrating from 0.2

- Upgrade Elixir to 1.18 or later. Jason is no longer a runtime dependency.
- The default server no longer assumes a `ref_data/` directory. Set
  `config :ref_data, path: "ref_data"` to keep the old location, or better, move the
  files to `priv/ref_data` as shown above.
- `use RefData` and successful flat lookups continue to work.
- Grouped results now use string-labelled tuples: `{"Oceania", options}` rather
  than nested atom-keyed keyword lists. Update any code inspecting groups directly.
- Missing keys return `nil` from `get` or `:error` from `fetch`. Use `get!` to raise.
- Duplicate names and malformed definitions fail startup with a file-specific error.
- Replace `use Mix.Config` with `import Config`. Use `priv/` and a runtime-resolved
  path for releases.
- The old callback declarations were removed; RefData is a concrete API rather
  than a behaviour. Internal server state and loader return values have changed.

## Development

Install the versions in `.tool-versions`, then run:

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test --warnings-as-errors
mix credo --strict
mix hex.audit
mix docs --warnings-as-errors
mix hex.build
```

CI tests Elixir 1.18, 1.19 and 1.20 across OTP 27 to 29. Test servers use isolated
temporary fixtures or the example datasets and do not require the default server.
