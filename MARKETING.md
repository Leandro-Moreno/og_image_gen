# Marketing Drafts for og_image_gen

## Distribution Plan

Post in order of priority:

1. **Elixir Forum** (https://elixirforum.com) — Post in "Your Libraries" category. This is the single most important channel for Elixir libraries. The forum community is active and supportive of new packages. Use a shorter version of the dev.to article, focused on the code.

2. **dev.to** — Full article (Draft 1 below). Tag with `elixir`, `phoenix`, `opensource`, `webdev`.

3. **LinkedIn** — Announcement post (Draft 2 below). Good for professional visibility and Shiko brand awareness.

4. **Reddit r/elixir** (https://reddit.com/r/elixir) — Short intro + link to hex.pm. This sub is small but engaged. Don't paste the full article — link to dev.to and let people ask questions.

5. **Twitter/X** — Short thread: problem statement, solution, example image, link. Tag @elaborracho (Jose Valim's handle) if feeling bold, and use #MyElixirStatus hashtag which the community watches.

6. **Elixir Slack** (#general or #libraries channel) — Brief announcement with link.

7. **Hacker News** (Show HN) — Only if you want broader reach. Title: "Show HN: OgImageGen -- Generate OG images in Elixir with SVG + Rust NIF, no Chrome needed"

---

## Draft 1: dev.to Article

---
title: "Stop Wrestling with OG Images: How We Built a Zero-Dependency Generator in Elixir"
published: false
tags: elixir, phoenix, opensource, webdev
cover_image: (use one of the example PNGs from the repo)
---

If you've ever tried to generate Open Graph images for a web app, you know the pain. Most solutions involve spinning up a headless Chrome instance, waiting for it to render HTML, taking a screenshot, and hoping it doesn't crash in production. Or you pay for a SaaS that does the same thing behind the scenes.

We ran into this exact problem at [Shiko](https://shiko.vet), our veterinary platform. We needed OG images for shared links — clinic pages, appointment confirmations, public pet profiles — and the existing options felt way too heavy for what's essentially "render some text on a gradient."

So we built **og_image_gen** and open-sourced it.

## What it does

`og_image_gen` generates 1200x630 PNG images from SVG templates using [resvg](https://github.com/nicolo-ribaudo/resvg-elixir), a Rust NIF. No Chrome. No Puppeteer. No wkhtmltoimage. No external binaries at all.

```elixir
{:ok, png} = OgImageGen.render("My Page Title",
  subtitle: "A great description",
  theme: :teal
)
File.write!("og.png", png)
```

That's it. You get a PNG binary back.

## The themes

It ships with 5 built-in gradient themes:

| Theme | Style |
|---|---|
| `:blue` | Deep blue gradient |
| `:teal` | Green-teal gradient |
| `:dark` | Dark gray gradient |
| `:coral` | Red-coral gradient |
| `:warning` | Yellow gradient, dark text |

And you can register your own at runtime:

```elixir
OgImageGen.register_theme(:brand, %OgImageGen.Theme{
  bg1: "#1a0533",
  bg2: "#2d0a4e",
  bg3: "#4a1280",
  text: "#ffffff",
  sub_opacity: "0.8"
})

{:ok, png} = OgImageGen.render("On Brand", theme: :brand)
```

## Integrating with Phoenix

Here's how we use it — a controller that generates OG images on demand:

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

Then in your HTML head:

```html
<meta property="og:image" content="https://yourapp.com/og/about?title=About+Us&theme=teal" />
```

The content-based hashing means the same inputs always produce the same output, so CDN caching works perfectly.

## Batch generation with diffing

If you prefer to pre-generate images at build time (for a static site, docs, or a manifest-driven approach), there's batch support with content-based diffing — it only regenerates images whose content actually changed:

```elixir
pages = [
  %{"path" => "home", "title" => "My App", "subtitle" => "Welcome", "theme" => "teal"},
  %{"path" => "about", "title" => "About Us", "theme" => "dark"},
  %{"path" => "pricing", "title" => "Pricing", "theme" => "coral"}
]

OgImageGen.process_batch(pages, fn path, png_binary ->
  File.write!("priv/static/og/#{path}.png", png_binary)
  :ok
end)
#=> %{generated: 3, skipped: 0, failed: 0}
```

Run it again without changes and everything gets skipped. Change one title and only that image regenerates.

## Path humanization

Small utility, but handy. If you don't have explicit titles for every route, the library can convert URL paths into readable titles:

```elixir
OgImageGen.humanize_path("productos/gatos")
#=> "Productos — Gatos"

OgImageGen.humanize_path("about-us")
#=> "About Us"
```

## Why not just use [other tool]?

| Approach | Drawback |
|---|---|
| Headless Chrome / Puppeteer | Heavy runtime dependency, memory hungry, slow |
| wkhtmltoimage | System binary, hard to deploy on containers |
| SaaS (Cloudinary, etc.) | Per-image cost, external dependency, latency |
| **og_image_gen** | Pure Elixir + Rust NIF, ~ms rendering, zero system deps |

The resvg NIF compiles with your project. No Docker tricks, no sidecar processes.

## Installation

```elixir
# mix.exs
def deps do
  [
    {:og_image_gen, "~> 0.1.0"}
  ]
end
```

## Links

- Hex: [hex.pm/packages/og_image_gen](https://hex.pm/packages/og_image_gen)
- GitHub: [github.com/Leandro-Moreno/og_image_gen](https://github.com/Leandro-Moreno/og_image_gen)
- Docs: [hexdocs.pm/og_image_gen](https://hexdocs.pm/og_image_gen)

This is MIT licensed and we'd love contributions — new themes, font handling improvements, template variations, whatever you think would be useful. Issues and PRs welcome.

Built with care by the [Shiko](https://shiko.vet) team.

---

## Draft 2: LinkedIn Post

---

We just published our first open-source Elixir package: **og_image_gen**

At Shiko, we needed Open Graph images (those preview cards you see when sharing links on social media) for our veterinary platform. The usual approach -- spinning up headless Chrome to screenshot HTML -- felt way too heavy for "render text on a gradient."

So we built a lightweight library that generates 1200x630 PNG images from SVG templates using a Rust NIF. No Chrome, no external binaries, no SaaS dependency. Just add it to your mix.exs and call `OgImageGen.render/2`.

What's included:
- 5 built-in gradient themes
- Custom theme registration
- Content-based hashing for smart caching
- Batch generation with diffing (only regenerates what changed)
- Path humanization for URL-to-title conversion
- Direct Phoenix integration

It's MIT licensed and available on Hex: https://hex.pm/packages/og_image_gen
Source: https://github.com/Leandro-Moreno/og_image_gen

We believe in giving back to the Elixir ecosystem that's made building Shiko possible. If you work with Phoenix and need OG images, give it a try. PRs and feedback welcome.

#Elixir #Phoenix #OpenSource #WebDev #OGImage #RustNIF #ElixirLang #SocialSharing

---

### Spanish version suggestion

Repost the same content in Spanish for the Latin American developer audience. Suggested opening:

"Acabamos de publicar nuestro primer paquete open-source en Elixir: og_image_gen

En Shiko, necesitabamos imagenes Open Graph para nuestra plataforma veterinaria..."

(Same structure, same links, add #DesarrolloWeb and #TechLatam hashtags)

---

## Suggested posting timeline

1. **Day 1**: Elixir Forum + Hex announcement (these are your core audience)
2. **Day 1-2**: dev.to article
3. **Day 2-3**: LinkedIn (English), then LinkedIn (Spanish)
4. **Day 3**: Reddit r/elixir
5. **Day 3**: Twitter/X with example images
6. **Week 2**: Consider Show HN if the Elixir community response is positive
