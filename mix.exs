defmodule Zachaeus.MixProject do
  use Mix.Project

  @source_url  "https://github.com/railsmechanic/nanoid"
  @maintainers ["Matthias Kalb"]

  def project do
    [
      name: "Zachaeus",
      app: :zachaeus,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      maintainers: @maintainers,
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:plug, "~> 1.8", optional: true},
      {:salty, "~> 0.1.3", hex: :libsalty},
      {:ex_doc, "~> 0.21.2", only: [:dev], runtime: false},
    ]
  end

  defp description do
    "Zachaeus is an easy to use licensing system inspired by JWT, which is using asymmetric signing."
  end

  defp package do
    [
      name: "zachaeus",
      licenses: ["MIT"],
      maintainers: @maintainers,
      links: %{"GitHub" => @source_url}
    ]
  end
end
