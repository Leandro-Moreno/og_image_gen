defmodule OgImageGen do
  @moduledoc """
  Generate Open Graph images (1200x630) for social sharing previews.

  Uses [resvg](https://hexdocs.pm/resvg) (Rust NIF) to render SVG templates to PNG.
  Images are keyed by a content hash, so identical title/subtitle/theme combinations
  produce the same file — enabling simple cache-by-filename strategies.

  ## Quick start

      # Generate a PNG binary
      {:ok, png} = OgImageGen.render("My Page Title", subtitle: "A great description", theme: :teal)
      File.write!("og.png", png)

  ## Themes

  Built-in themes: `:blue`, `:teal`, `:dark`, `:coral`, `:warning`.
  Register custom themes at compile time or runtime:

      OgImageGen.register_theme(:brand, %OgImageGen.Theme{
        bg1: "#1a0533",
        bg2: "#2d0a4e",
        bg3: "#4a1280",
        text: "#ffffff",
        sub_opacity: "0.8"
      })

  ## Batch generation

  Process multiple pages at once with content-based diffing:

      pages = [
        %{path: "home", title: "My App", subtitle: "Welcome", theme: "teal"},
        %{path: "about", title: "About Us", theme: "dark"}
      ]

      OgImageGen.process_batch(pages, fn path, png_binary ->
        # Upload to S3, R2, local disk, etc.
        File.write!("priv/static/og/\#{path}.png", png_binary)
      end)

  ## Configuration

      config :og_image_gen,
        width: 1200,           # default
        height: 630,           # default
        font_dirs: ["/path/to/fonts"],
        default_theme: :blue,
        logo_svg: \\"<path d=\\\\"...\\\\"/>\\"   # SVG inner content for logo
  """

  alias OgImageGen.{Renderer, Theme}

  @type render_opt ::
          {:subtitle, String.t()}
          | {:theme, atom() | String.t()}
          | {:logo, String.t() | nil}
          | {:font_dirs, [String.t()]}
  @type batch_result :: %{generated: non_neg_integer(), skipped: non_neg_integer(), failed: non_neg_integer()}

  @doc """
  Renders an OG image and returns the PNG binary.

  ## Options

    * `:subtitle` — secondary text below the title (default: `""`)
    * `:theme` — theme name as atom or string (default: configured default or `:blue`)
    * `:logo` — SVG inner content for logo override, or `nil` to use configured logo

  ## Examples

      {:ok, png} = OgImageGen.render("Hello World")
      {:ok, png} = OgImageGen.render("Products", subtitle: "Browse our catalog", theme: :coral)
  """
  @spec render(String.t(), [render_opt()]) :: {:ok, binary()} | {:error, String.t()}
  def render(title, opts \\ []) do
    Renderer.render(title, opts)
  end

  @doc """
  Returns a deterministic content hash for a title/subtitle/theme combination.

  Useful for cache keys and filename generation.

  ## Examples

      OgImageGen.content_hash("My Title", "subtitle", :blue)
      #=> "a1b2c3d4"
  """
  @spec content_hash(String.t(), String.t(), atom() | String.t()) :: String.t()
  def content_hash(title, subtitle \\ "", theme \\ :blue) do
    theme_str = to_string(theme)

    :crypto.hash(:md5, "#{title}|#{subtitle}|#{theme_str}")
    |> Base.hex_encode32(case: :lower, padding: false)
    |> binary_part(0, 8)
  end

  @doc """
  Processes a batch of pages, calling `upload_fn` for each new or changed image.

  Each page is a map with keys: `"path"`, `"title"`, `"subtitle"` (optional),
  `"theme"` (optional). The function uses content hashing to skip pages whose
  content hasn't changed since the last batch.

  `upload_fn` receives `(path, png_binary)` and should return `:ok` or `{:error, reason}`.

  ## Examples

      OgImageGen.process_batch(pages, fn path, png ->
        S3.put_object("bucket", "og/\#{path}.png", png) |> ExAws.request()
        :ok
      end)
  """
  @spec process_batch([map()], (String.t(), binary() -> :ok | {:error, term()}), map()) :: batch_result()
  def process_batch(pages, upload_fn, previous_manifest \\ %{}) when is_list(pages) do
    results =
      Enum.map(pages, fn page ->
        path = Map.get(page, "path", "")
        title = Map.get(page, "title", "OgImageGen")
        subtitle = Map.get(page, "subtitle", "")
        theme = Map.get(page, "theme", "blue")
        hash = content_hash(title, subtitle, theme)

        prev_hash = get_in(previous_manifest, [path, "hash"])

        if prev_hash == hash do
          :skipped
        else
          case render(title, subtitle: subtitle, theme: String.to_existing_atom(theme)) do
            {:ok, png} ->
              case upload_fn.(path, png) do
                :ok -> {:generated, path, %{"title" => title, "subtitle" => subtitle, "theme" => theme, "hash" => hash}}
                {:error, _} -> :failed
              end

            {:error, _} ->
              :failed
          end
        end
      end)

    %{
      generated: Enum.count(results, &match?({:generated, _, _}, &1)),
      skipped: Enum.count(results, &(&1 == :skipped)),
      failed: Enum.count(results, &(&1 == :failed))
    }
  end

  @doc """
  Returns the list of available theme names (built-in + registered).
  """
  @spec available_themes() :: [atom()]
  def available_themes, do: Theme.available()

  @doc """
  Registers a custom theme at runtime.

  ## Examples

      OgImageGen.register_theme(:brand, %OgImageGen.Theme{
        bg1: "#1a0533", bg2: "#2d0a4e", bg3: "#4a1280",
        text: "#ffffff", sub_opacity: "0.8"
      })
  """
  @spec register_theme(atom(), Theme.t()) :: :ok
  def register_theme(name, %Theme{} = theme) do
    Theme.register(name, theme)
  end

  @doc """
  Humanizes a URL path into a readable title.

  Useful as a fallback when no explicit title is provided.

  ## Examples

      OgImageGen.humanize_path("productos/gatos")
      #=> "Productos — Gatos"

      OgImageGen.humanize_path("/blog/my-first-post/index")
      #=> "Blog — My First Post"
  """
  @spec humanize_path(String.t()) :: String.t()
  def humanize_path(path) do
    path
    |> String.trim_leading("/")
    |> String.trim_trailing("/")
    |> String.split("/")
    |> Enum.reject(&(&1 in ["", "index"]))
    |> case do
      [] ->
        "Home"

      segments ->
        segments
        |> Enum.map(fn segment ->
          segment
          |> String.replace(~r/[-_]/, " ")
          |> String.split(" ")
          |> Enum.map(&String.capitalize/1)
          |> Enum.join(" ")
        end)
        |> Enum.join(" — ")
    end
  end
end
