defmodule Err.MixProject do
  use Mix.Project

  @source_url "https://github.com/leandrocp/err"
  @version "0.2.0"

  def project do
    [
      app: :err,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      package: package(),
      docs: docs(),
      deps: deps(),
      aliases: aliases(),
      name: "Err",
      source_url: @source_url,
      description:
        "Tiny library that makes working with tagged {:ok, value} and {:error, reason} tagged tuples more ergonomic and expressive."
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        docs: :docs,
        "hex.publish": :docs
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Leandro Pereira"],
      licenses: ["MIT"],
      links: %{
        Changelog: "https://hexdocs.pm/err/changelog.html",
        GitHub: @source_url
      },
      files: [
        "mix.exs",
        "lib",
        "README.md",
        "LICENSE",
        "CHANGELOG.md"
      ]
    ]
  end

  defp docs do
    [
      main: "Err",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["CHANGELOG.md"],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :docs}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "compile"]
    ]
  end
end
