defmodule Centra.MixProject do
  use Mix.Project

  def project do
    [
      app: :centra,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Centra,[]},
      extra_applications: [:logger, :gen_state_machine, :logger_file_backend]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_state_machine, "~> 2.0"},
      {:logger_file_backend,
       git: "https://github.com/onkel-dirtus/logger_file_backend.git", tag: "v0.0.11"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
