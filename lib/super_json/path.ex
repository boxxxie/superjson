defmodule SuperJSON.Path do
  @moduledoc """
  Helper module for parsing and stringifying SuperJSON dot-notated and escaped path strings
  (e.g., `"user.created_at"`, `"items.0.name"`, `"a\\.1.b"`, `"a\\\\\\.1.b"`).
  """

  @doc """
  Parses a SuperJSON path string into a list of keys and `Access.at/1` index structs.

  ## Examples

      iex> SuperJSON.Path.parse("a.b.c")
      ["a", "b", "c"]

      iex> SuperJSON.Path.parse("items.0")
      ["items", Access.at(0)]

      iex> SuperJSON.Path.parse("a\\\\.1.b")
      ["a.1", "b"]
  """
  @spec parse(binary()) :: [binary() | (term() -> term())]
  def parse(path_string) when is_binary(path_string) do
    path_string
    |> do_parse([], "")
    |> Enum.map(fn segment ->
      case Integer.parse(segment) do
        {num, ""} -> Access.at(num)
        _ -> segment
      end
    end)
  end

  defp do_parse(<<"\\\\", rest::binary>>, segments, current) do
    do_parse(rest, segments, current <> "\\")
  end

  defp do_parse(<<"\\.", rest::binary>>, segments, current) do
    do_parse(rest, segments, current <> ".")
  end

  defp do_parse(<<"\\", rest::binary>>, segments, current) do
    do_parse(rest, segments, current)
  end

  defp do_parse(<<".", rest::binary>>, segments, current) do
    do_parse(rest, segments ++ [current], "")
  end

  defp do_parse(<<c::utf8, rest::binary>>, segments, current) do
    do_parse(rest, segments, current <> <<c::utf8>>)
  end

  defp do_parse("", segments, current) do
    segments ++ [current]
  end

  @doc """
  Stringifies a list of keys and integers into a SuperJSON path string.
  Dots and backslashes in keys are escaped.

  ## Examples

      iex> SuperJSON.Path.stringify(["a", 0, "b"])
      "a.0.b"

      iex> SuperJSON.Path.stringify(["a.1", "b"])
      "a\\\\.1.b"
  """
  @spec stringify([binary() | integer()]) :: binary()
  def stringify([]), do: ""

  def stringify(path) when is_list(path) do
    path
    |> Enum.map(fn
      key when is_integer(key) -> Integer.to_string(key)
      key when is_binary(key) -> escape_key(key)
      key when is_atom(key) -> escape_key(Atom.to_string(key))
    end)
    |> Enum.join(".")
  end

  defp escape_key(key) do
    key
    |> String.replace("\\", "\\\\")
    |> String.replace(".", "\\.")
  end
end
