defmodule DbSampler.MixProject do
  use Mix.Project

  def project do
    [
      app: :db_sampler,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "DbSampler",
      docs: [
        main: "DbSampler.Sampler",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {DbSampler.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:postgrex, "~> 0.21.1"},
      {:jason, "~> 1.4.4"},
      {:ex_doc, "~> 0.39.3", only: :dev, runtime: false}
    ]
  end
end
