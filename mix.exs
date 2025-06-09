defmodule Gemini.MixProject do
  use Mix.Project

  @version "0.0.1"

  def project do
    [
      app: :gemini,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: "Comprehensive Elixir client for Google's Gemini API",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Gemini.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:typed_struct, "~> 0.3"},
      {:joken, "~> 2.6"},
      {:telemetry, "~> 1.2"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Gemini",
      source_ref: "v#{@version}",
      source_url: "https://github.com/nshkrdotcom/gemini_ex"
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/nshkrdotcom/gemini_ex"}
    ]
  end
end
