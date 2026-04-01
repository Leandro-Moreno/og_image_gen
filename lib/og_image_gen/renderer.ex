defmodule OgImageGen.Renderer do
  @moduledoc false

  # Internal module that handles SVG building and resvg rendering.

  require Logger

  alias OgImageGen.Theme

  @width 1200
  @height 630

  @spec render(String.t(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def render(title, opts) do
    subtitle = Keyword.get(opts, :subtitle, "")
    theme_name = Keyword.get(opts, :theme, default_theme())
    logo = Keyword.get(opts, :logo) || configured_logo()

    theme = Theme.get(theme_name)
    svg = build_svg(title, subtitle, theme, logo)

    font_dirs = Keyword.get(opts, :font_dirs) || configured_font_dirs()

    resvg_opts =
      [resources_dir: System.tmp_dir!()] ++
        if font_dirs != [] do
          [font_dirs: font_dirs, skip_system_fonts: true]
        else
          [skip_system_fonts: false]
        end

    case Resvg.svg_string_to_png_buffer(svg, resvg_opts) do
      {:ok, png_buffer} ->
        {:ok, IO.iodata_to_binary(png_buffer)}

      {:error, reason} ->
        {:error, "OG image rendering failed: #{inspect(reason)}"}
    end
  end

  # ── SVG template ──

  defp build_svg(title, subtitle, theme, logo) do
    subtitle_block =
      if subtitle != "" do
        ~s(<text x="80" y="#{title_y(title) + 60}" font-family="Inter, sans-serif" font-size="24" fill="#{theme.text}" opacity="#{theme.sub_opacity}">#{escape(truncate(subtitle, 80))}</text>)
      else
        ""
      end

    logo_block =
      if logo && logo != "" do
        """
        <g transform="translate(80, 80) scale(0.35)">
          #{logo}
        </g>
        """
      else
        ""
      end

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{@width}" height="#{@height}" viewBox="0 0 #{@width} #{@height}">
      <defs>
        <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#{theme.bg1}"/>
          <stop offset="50%" stop-color="#{theme.bg2}"/>
          <stop offset="100%" stop-color="#{theme.bg3}"/>
        </linearGradient>
      </defs>

      <!-- Background -->
      <rect width="#{@width}" height="#{@height}" fill="url(#bg)"/>

      <!-- Decorative circles -->
      <circle cx="#{@width + 100}" cy="-100" r="250" fill="white" opacity="0.05"/>
      <circle cx="-50" cy="#{@height + 150}" r="200" fill="white" opacity="0.03"/>

      <!-- Logo -->
      #{logo_block}

      <!-- Title -->
      #{title_lines(title, theme.text)}

      <!-- Subtitle -->
      #{subtitle_block}

      <!-- Accent line -->
      <rect y="#{@height - 6}" width="#{@width}" height="6" fill="white" opacity="0.2"/>
    </svg>
    """
  end

  defp title_lines(title, color) do
    truncated = truncate(title, 50)
    words = String.split(truncated)
    lines = wrap_words(words, 30)
    base_y = 320

    lines
    |> Enum.with_index()
    |> Enum.map(fn {line, i} ->
      y = base_y + i * 52

      ~s(<text x="80" y="#{y}" font-family="Inter, sans-serif" font-size="44" font-weight="700" fill="#{color}">#{escape(line)}</text>)
    end)
    |> Enum.join("\n    ")
  end

  defp title_y(title) do
    lines = title |> truncate(50) |> String.split() |> wrap_words(30) |> length()
    320 + (lines - 1) * 52
  end

  defp wrap_words(words, max_chars) do
    {lines, current} =
      Enum.reduce(words, {[], ""}, fn word, {lines, current} ->
        candidate = if current == "", do: word, else: "#{current} #{word}"

        if String.length(candidate) > max_chars and current != "" do
          {[current | lines], word}
        else
          {lines, candidate}
        end
      end)

    Enum.reverse([current | lines])
  end

  defp truncate(text, max) do
    if String.length(text) > max do
      String.slice(text, 0, max - 3) <> "..."
    else
      text
    end
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp default_theme do
    Application.get_env(:og_image_gen, :default_theme, :blue)
  end

  defp configured_logo do
    Application.get_env(:og_image_gen, :logo_svg, nil)
  end

  defp configured_font_dirs do
    Application.get_env(:og_image_gen, :font_dirs, [])
  end
end
