# RefData

[![Elixir CI](https://github.com/abarr/ref_data/actions/workflows/elixir.yml/badge.svg)](https://github.com/abarr/ref_data/actions/workflows/elixir.yml)

RefData loads JSON reference datasets into memory for form options and other lookups,
without a database. It uses Elixir's built-in `JSON` module and has no runtime dependencies.

## Requirements and installation

Elixir 1.20 or later and a compatible Erlang/OTP version are required. Development is
pinned to Elixir 1.20.5 and OTP 29.1.2 in `.tool-versions`.

```elixir
def deps do
  [{:ref_data, "~> 0.3.0"}]
end
```

## Configuration and releases

For compatibility, RefData starts a default server and reads `*.json` files from
`ref_data/` relative to the working directory. An empty directory is valid; a missing
directory or invalid file stops startup with an error identifying the path.

For releases, put datasets in your application's `priv/ref_data/` directory so Mix
bundles them with the application. Resolve the path at runtime in `config/runtime.exs`:

```elixir
import Config

config :ref_data,
  path: Application.app_dir(:my_app, "priv/ref_data")
```

Alternatively, let your application supervise RefData explicitly. Disable the default
server in your configuration:

```elixir
import Config

config :ref_data, start_default_server: false
```

Add an instance to your application's supervision tree:

```elixir
children = [
  {RefData, name: MyApp.ReferenceData, path: Application.app_dir(:my_app, "priv/ref_data")}
]
```

Query it with `RefData.get("countries", server: MyApp.ReferenceData)`. Instances have
independent data. Use different names for multiple instances, or `name: nil` for an
unnamed process and query it by PID. Data is loaded at startup; restart an instance
to load changed files.

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

With the default server:

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

Both wrappers expose `list_all_keys/0`, `get/1,2`, `fetch/1,2` and `get!/1,2`.

## Migrating from 0.2

- Upgrade Elixir to 1.20 or later. Jason is no longer a runtime dependency.
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

CI checks Elixir 1.20.5 on OTP 27, 28 and 29.1.2. Test servers use isolated temporary
fixtures or the example datasets and do not require the default application server.
