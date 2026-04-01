defmodule OgImageGen.Theme do
  @moduledoc """
  Defines color themes for OG image generation.

  Each theme specifies a three-stop gradient background and text styling.

  ## Built-in themes

  | Name      | Style                           |
  |-----------|--------------------------------------|
  | `:blue`   | Deep blue gradient, white text       |
  | `:teal`   | Green-teal gradient, white text      |
  | `:dark`   | Dark gray gradient, white text       |
  | `:coral`  | Red-coral gradient, white text       |
  | `:warning`| Yellow gradient, dark text           |

  ## Custom themes

      OgImageGen.register_theme(:brand, %OgImageGen.Theme{
        bg1: "#1a0533",
        bg2: "#2d0a4e",
        bg3: "#4a1280",
        text: "#ffffff",
        sub_opacity: "0.8"
      })
  """

  @type t :: %__MODULE__{
          bg1: String.t(),
          bg2: String.t(),
          bg3: String.t(),
          text: String.t(),
          sub_opacity: String.t()
        }

  defstruct [:bg1, :bg2, :bg3, :text, sub_opacity: "0.8"]

  @builtin_themes %{
    blue: %{bg1: "#0d0d5d", bg2: "#1a1a8a", bg3: "#2929b0", text: "#ffffff", sub_opacity: "0.8"},
    teal: %{bg1: "#1B7F6A", bg2: "#22a085", bg3: "#28c09f", text: "#ffffff", sub_opacity: "0.8"},
    dark: %{bg1: "#2A2D34", bg2: "#3d4250", bg3: "#52586b", text: "#ffffff", sub_opacity: "0.8"},
    coral: %{bg1: "#c44547", bg2: "#E85F61", bg3: "#f08082", text: "#ffffff", sub_opacity: "0.8"},
    warning: %{bg1: "#e6b800", bg2: "#FFD766", bg3: "#ffe699", text: "#2A2D34", sub_opacity: "0.7"}
  }

  defp to_struct(%__MODULE__{} = t), do: t
  defp to_struct(map) when is_map(map), do: struct(__MODULE__, map)

  @table :og_image_gen_custom_themes

  @doc false
  def ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    end

    :ok
  end

  @doc "Returns the theme struct for the given name, or the default theme."
  @spec get(atom() | String.t()) :: t()
  def get(name) when is_binary(name) do
    get(String.to_existing_atom(name))
  rescue
    ArgumentError -> get(:blue)
  end

  def get(name) when is_atom(name) do
    case Map.get(@builtin_themes, name) do
      nil -> get_custom(name)
      theme -> to_struct(theme)
    end
  end

  @doc "Returns all available theme names."
  @spec available() :: [atom()]
  def available do
    builtin = Map.keys(@builtin_themes)

    custom =
      try do
        ensure_table()
        :ets.tab2list(@table) |> Enum.map(&elem(&1, 0))
      rescue
        _ -> []
      end

    Enum.uniq(builtin ++ custom)
  end

  @doc "Registers a custom theme."
  @spec register(atom(), t()) :: :ok
  def register(name, %__MODULE__{} = theme) do
    ensure_table()
    :ets.insert(@table, {name, theme})
    :ok
  end

  defp get_custom(name) do
    try do
      ensure_table()

      case :ets.lookup(@table, name) do
        [{^name, theme}] -> theme
        [] -> to_struct(Map.get(@builtin_themes, :blue))
      end
    rescue
      _ -> to_struct(Map.get(@builtin_themes, :blue))
    end
  end
end
