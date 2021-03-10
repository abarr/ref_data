# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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



