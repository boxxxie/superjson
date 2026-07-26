defmodule SuperJSON.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/boxxxie/superjson"

  def project do
    [
      app: :superjson,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    A SuperJSON decoder and encoder for Elixir, enabling seamless rehydration of complex JS/TS types
    (Dates, MapSets, Maps, BigInts, Regexps, and referential equalities) from SuperJSON payloads.
    """
  end

  defp package do
    [
      name: "superjson",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "SuperJSON",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
