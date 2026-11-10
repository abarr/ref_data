# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-11-10

### Added
- `mix ref_data.init` creates `priv/ref_data/` with an example dataset and prints the
  configuration to add.
- `RefData.label/3` returns the label for a stored value, for displaying saved choices.
- Immutable catalogs loaded with `RefData.load/1` and selected with `source:`.
- Submitted-value validation with canonical JSON values and explicit errors for
  unknown, disabled and ambiguous choices, including nested groups.
- Concurrent-read and storage lifecycle tests.
- Direct lookup API with `fetch/2`, `get!/2` and configurable server selection.
- Explicit supervision and independent named or unnamed instances.
- File-specific validation errors and duplicate dataset detection.
- Tests for malformed data, missing keys, empty datasets and grouped disabling.

### Changed
- Require Elixir 1.18 or later (for the built-in `JSON` module).
- **Breaking:** the default server starts only when `config :ref_data, path: ...` is
  set, so adding the dependency no longer fails startup when `ref_data/` is absent.
- Pin development to Elixir 1.20.5 / OTP 29.1.2 and test Elixir 1.18 to 1.20 in CI.
- Replace the Jason runtime dependency with built-in `JSON` decoding.
- Update all development dependencies and the lockfile.
- Represent grouped options as string-labelled tuples instead of atom-keyed lists.
- Return `nil` for missing `get` lookups without crashing the shared server.
- Use protected ETS tables for shared datasets; local reads bypass the owner mailbox.
- Keep immutable catalog lookups process-free and preserve option order.
- Publish tables through a supervised Registry and resolve restarted instances by PID.
- Preserve legacy server messages and remote-node lookups.
- Document release-safe paths, current configuration syntax and migration steps.

### Fixed
- Disabling options in grouped datasets.
- Dynamic atom creation from JSON group labels.
- Crashes on empty datasets and unclear errors for invalid input.

## [0.2.1] - 2021-03-10

### Changed
- Documentation, package metadata and CI updates only; no library changes.

## [0.2.0] - 2021-03-10

### Added
- Supports more detailed `json` definitions to allow developers to add custom values 

### Fixed
- Modified generation of `maps` from `json` definitions to match the casing between key and value (e.g. `{ "genders": ["Male", ...]}`)
will now create a map `%{ "name" => "genders", "values" => [[ "key" => "Male", "value" => "Male"], ...]}` rather than 
`%{ "name" => "genders", "values" => [[ "key" => "Male", "value" => "male"], ...]}`

### Changed
- Removed the use of :ets, it is redundant given the nature of a GenServer and its role holding state
- Modified the Jason.decode funtion to include the `string: :copy` option. The RefData server is designed to run while your application is running
and the default `reference` option stops teh garbage collection of the original `json` definitons
- Removed the use of the `:raw` key as it was redundant and the library no longer stores the raw json



