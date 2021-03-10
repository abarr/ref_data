defmodule RefData.MixProject do
  use Mix.Project

  def project do
    [
      app: :ref_data,
      version: "0.2.0",
      elixir: "~> 1.10",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      name: "RefData",
      source_url: "https://github.com/abarr/ref_data",
      docs: [
        extras: ["README.md"]
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
      "test.ci": ["test --color --max-cases=10"],
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:credo, "~> 1.5"}
    ]
  end

  defp description() do
    "RefData is a library for Phoenix projects that lets you provide reference data
    for your forms (e.g. Gender) without using a database table. "
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/abarr/ref_data"}
    ]
  end
end
