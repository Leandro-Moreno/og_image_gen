defmodule OgImageGenTest do
  use ExUnit.Case, async: true

  describe "content_hash/3" do
    test "returns deterministic hash" do
      hash1 = OgImageGen.content_hash("Title", "Sub", :blue)
      hash2 = OgImageGen.content_hash("Title", "Sub", :blue)
      assert hash1 == hash2
    end

    test "different content produces different hash" do
      hash1 = OgImageGen.content_hash("Title A", "", :blue)
      hash2 = OgImageGen.content_hash("Title B", "", :blue)
      refute hash1 == hash2
    end

    test "hash is 8 characters" do
      hash = OgImageGen.content_hash("Hello", "", :teal)
      assert String.length(hash) == 8
    end
  end

  describe "humanize_path/1" do
    test "converts path segments to title case" do
      assert OgImageGen.humanize_path("productos/gatos") == "Productos — Gatos"
    end

    test "strips index segments" do
      assert OgImageGen.humanize_path("/blog/my-post/index") == "Blog — My Post"
    end

    test "handles empty path" do
      assert OgImageGen.humanize_path("") == "Home"
    end

    test "replaces dashes and underscores with spaces" do
      assert OgImageGen.humanize_path("my-cool_page") == "My Cool Page"
    end
  end

  describe "available_themes/0" do
    test "includes built-in themes" do
      themes = OgImageGen.available_themes()
      assert :blue in themes
      assert :teal in themes
      assert :dark in themes
      assert :coral in themes
      assert :warning in themes
    end
  end

  describe "register_theme/2" do
    test "registers and makes available a custom theme" do
      theme = %OgImageGen.Theme{
        bg1: "#111",
        bg2: "#222",
        bg3: "#333",
        text: "#fff"
      }

      assert :ok = OgImageGen.register_theme(:custom_test, theme)
      assert :custom_test in OgImageGen.available_themes()
    end
  end

  describe "render/2" do
    test "generates a PNG binary" do
      assert {:ok, png} = OgImageGen.render("Test Title")
      # PNG magic bytes
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "renders with subtitle and theme" do
      assert {:ok, png} = OgImageGen.render("Hello", subtitle: "World", theme: :coral)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "renders with all themes" do
      for theme <- [:blue, :teal, :dark, :coral, :warning] do
        assert {:ok, _png} = OgImageGen.render("Theme: #{theme}", theme: theme)
      end
    end
  end
end
