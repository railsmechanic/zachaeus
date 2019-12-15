defmodule Zachaeus.MixProject do
  use Mix.Project

  def project do
    [
      app: :zachaeus,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: name(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:salty, "~> 0.1.3", hex: :libsalty},
      {:ex_doc, "~> 0.21.2", only: [:dev]}
    ]
  end

  defp name do
    "Zachaeus"
  end

  defp description do
    "Zachaeus is an easy to use licensing system, which uses asymmetric signing for validating license tokens."
  end

  defp package do
    [
      name: "zachaeus",
      maintainers: ["Matthias Kalb"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/railsmechanic/zachaeus"}
    ]
  end
end
