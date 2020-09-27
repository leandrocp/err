defmodule Err.MixProject do
  use Mix.Project

  @name "Err"
  @version "0.1.0"
  @repo_url "https://github.com/leandrocp/err"

  def project do
    [
      app: :err,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: "A tiny library for dealing with errors.",
      source_url: @repo_url,
      homepage_url: @repo_url,

      # Docs
      name: @name,
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.22.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Leandro Cesquini Pereira"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end

  defp docs do
    [
      main: @name,
      source_ref: "v#{@version}",
      source_url: @repo_url
    ]
  end
end
