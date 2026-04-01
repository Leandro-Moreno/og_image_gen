defmodule OgImageGen.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/Leandro-Moreno/og_image_gen"

  def project do
    [
      app: :og_image_gen,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "OgImageGen",
      description: """
      Generate beautiful Open Graph images for social sharing using SVG templates
      and resvg (Rust NIF). Supports themed gradients, custom typography,
      content-based caching, and batch generation via manifest.
      """
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:resvg, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Shiko" => "https://shiko.vet"
      },
      maintainers: ["Shiko Team"],
      files: ~w(lib priv/examples .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
