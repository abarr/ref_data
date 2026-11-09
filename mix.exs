defmodule RefData.MixProject do
  use Mix.Project

  def project do
    [
      app: :ref_data,
      version: "0.3.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      name: "RefData",
      source_url: "https://github.com/abarr/ref_data",
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RefData.Application, []}
    ]
  end

  defp aliases do
    [
      "test.ci": ["test --color --max-cases=10"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.40.4", only: :dev, runtime: false},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false}
    ]
  end

  defp description() do
    "Reference data for Phoenix forms (e.g. countries, statuses) loaded from JSON files " <>
      "instead of database tables, with select options, labels and submitted-value validation."
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* CHANGELOG* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/abarr/ref_data"}
    ]
  end
end
