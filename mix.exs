defmodule Thunk.MixProject do
  use Mix.Project

  def project do
    [
      app: :thunk,
      version: "0.2.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Laziness in Elixir",
      source_url: "https://github.com/jakeKonrad/thunk"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "thunk",
      maintainers: ["jakegkonrad@gmail.com"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jakeKonrad/thunk"}
    ]
  end
end
