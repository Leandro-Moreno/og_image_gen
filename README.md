# OgImageGen

Generate beautiful Open Graph images for social sharing using SVG templates and
[resvg](https://github.com/nicolo-ribaudo/resvg-elixir) (Rust NIF).

Built by the [Shiko](https://shiko.vet) team.

## Examples

| With logo (blue) | Without logo (teal) |
|---|---|
| ![Blue with Shiko logo](priv/examples/example-blue-logo.png) | ![Teal without logo](priv/examples/example-teal-no-logo.png) |

| With logo (coral) | Without logo (dark) |
|---|---|
| ![Coral with Shiko logo](priv/examples/example-coral-logo.png) | ![Dark without logo](priv/examples/example-dark-no-logo.png) |

| Warning theme with logo |
|---|
| ![Warning with Shiko logo](priv/examples/example-warning-logo.png) |

## Features

- **SVG → PNG** rendering via resvg (no browser, no headless Chrome, no wkhtmltoimage)
- **5 built-in themes** with gradient backgrounds (blue, teal, dark, coral, warning)
- **Custom themes** — register your own at runtime
- **Content-based hashing** — same content = same hash, perfect for caching
- **Batch generation** with diff support (only regenerates changed pages)
- **Zero external dependencies** — no system binaries needed beyond Erlang/Elixir

## Installation

Add `og_image_gen` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:og_image_gen, "~> 0.1.0"}
  ]
end
```

## Quick start

```elixir
# Generate a PNG binary
{:ok, png} = OgImageGen.render("My Page Title", subtitle: "A great description", theme: :teal)
File.write!("og.png", png)
```

## Configuration

```elixir
config :og_image_gen,
  default_theme: :blue,
  font_dirs: ["/path/to/fonts"],   # e.g. Inter font directory
  logo_svg: "<path d=\"...\"/>"     # SVG inner content (no <svg> wrapper)
```

## Themes

| Theme      | Style                       |
|------------|-----------------------------|
| `:blue`    | Deep blue gradient          |
| `:teal`    | Green-teal gradient         |
| `:dark`    | Dark gray gradient          |
| `:coral`   | Red-coral gradient          |
| `:warning` | Yellow gradient, dark text  |

### Custom themes

```elixir
OgImageGen.register_theme(:brand, %OgImageGen.Theme{
  bg1: "#1a0533",
  bg2: "#2d0a4e",
  bg3: "#4a1280",
  text: "#ffffff",
  sub_opacity: "0.8"
})

{:ok, png} = OgImageGen.render("My Brand Page", theme: :brand)
```

## Batch generation

Process multiple pages with content-based diffing — only new or changed content
gets re-rendered:

```elixir
pages = [
  %{"path" => "home", "title" => "My App", "subtitle" => "Welcome", "theme" => "teal"},
  %{"path" => "about", "title" => "About Us", "theme" => "dark"}
]

OgImageGen.process_batch(pages, fn path, png_binary ->
  # Upload to S3, R2, local disk, wherever
  File.write!("priv/static/og/#{path}.png", png_binary)
  :ok
end)
#=> %{generated: 2, skipped: 0, failed: 0}
```

## Content hashing

Each title/subtitle/theme combination produces a deterministic 8-character hash,
useful for cache-busting filenames:

```elixir
OgImageGen.content_hash("My Title", "subtitle", :blue)
#=> "a1b2c3d4"
```

## Path humanization

Convert URL paths to readable titles as a fallback:

```elixir
OgImageGen.humanize_path("productos/gatos")
#=> "Productos — Gatos"
```

## Integration with Phoenix

Use it in a controller to serve OG images on-demand:

```elixir
def og_image(conn, %{"path" => path} = params) do
  title = params["title"] || OgImageGen.humanize_path(path)
  theme = String.to_existing_atom(params["theme"] || "blue")

  case OgImageGen.render(title, subtitle: params["subtitle"] || "", theme: theme) do
    {:ok, png} ->
      conn
      |> put_resp_header("content-type", "image/png")
      |> put_resp_header("cache-control", "public, max-age=604800")
      |> send_resp(200, png)

    {:error, _} ->
      send_resp(conn, 500, "Failed to generate image")
  end
end
```

## License

MIT — see [LICENSE](LICENSE).
