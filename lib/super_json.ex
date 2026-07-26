defmodule SuperJSON do
  @moduledoc """
  SuperJSON encoder and decoder for Elixir.

  SuperJSON extends JSON with annotations (`meta`) that describe rich JavaScript/TypeScript
  data types (Dates, BigInts, Regexps, Sets, Maps, undefined, referential equalities).
  This module allows you to encode and decode these payloads transparently.
  """

  alias SuperJSON.Path

  # --- ENCODE ---

  @doc """
  Encodes a native Elixir term into a SuperJSON-compliant map `{"json" => ..., "meta" => ...}`.
  """
  @spec encode(term()) :: map()
  def encode(term) do
    {json, meta} = do_encode(term)

    result = %{"json" => json}

    case meta do
      m when is_map(m) and map_size(m) == 0 ->
        result

      m when is_map(m) ->
        Map.put(result, "meta", %{"values" => m})

      l when is_list(l) ->
        Map.put(result, "meta", %{"values" => l})
    end
  end

  @doc """
  Encodes a native Elixir term into a raw SuperJSON binary string.
  """
  @spec encode!(term()) :: binary()
  def encode!(term) do
    term |> encode() |> Jason.encode!()
  end

  # Primitives
  defp do_encode(val) when is_binary(val) or is_boolean(val) or is_nil(val), do: {val, %{}}
  defp do_encode(val) when is_float(val), do: {val, %{}}

  defp do_encode(:nan), do: {"NaN", ["number"]}
  defp do_encode(:inf), do: {"Infinity", ["number"]}
  defp do_encode(:"-inf"), do: {"-Infinity", ["number"]}

  defp do_encode(val) when is_integer(val) do
    if val > 9_007_199_254_740_991 or val < -9_007_199_254_740_991 do
      {Integer.to_string(val), ["bigint"]}
    else
      {val, %{}}
    end
  end

  # Structs
  defp do_encode(%{__struct__: struct_name} = struct) do
    case struct_name do
      DateTime ->
        {DateTime.to_iso8601(struct), ["Date"]}

      NaiveDateTime ->
        {NaiveDateTime.to_iso8601(struct) <> "Z", ["Date"]}

      Date ->
        {Date.to_iso8601(struct) <> "T00:00:00Z", ["Date"]}

      URI ->
        {URI.to_string(struct), ["URL"]}

      Regex ->
        opts =
          if is_binary(struct.opts) do
            struct.opts
            |> String.graphemes()
            |> Enum.sort()
            |> Enum.join("")
          else
            struct.opts
            |> Enum.map(fn
              :caseless -> "i"
              :multiline -> "m"
              :dotall -> "s"
              :extended -> "x"
              :unicode -> "u"
              _ -> ""
            end)
            |> Enum.sort()
            |> Enum.join("")
          end

        {"/#{struct.source}/#{opts}", ["regexp"]}

      MapSet ->
        {json_list, meta} = do_encode_list(MapSet.to_list(struct))

        if map_size(meta) > 0 do
          {json_list, ["set", meta]}
        else
          {json_list, ["set"]}
        end

      RuntimeError ->
        {%{"name" => "Error", "message" => struct.message}, ["Error"]}

      _ ->
        do_encode_map(Map.from_struct(struct))
    end
  end

  # Maps
  defp do_encode(val) when is_map(val) do
    is_plain = Enum.all?(val, fn {k, _v} -> is_binary(k) or is_atom(k) end)

    if is_plain do
      do_encode_map(val)
    else
      do_encode_js_map(val)
    end
  end

  # Lists & Tuples
  defp do_encode(val) when is_list(val), do: do_encode_list(val)
  defp do_encode(val) when is_tuple(val), do: do_encode_list(Tuple.to_list(val))

  defp do_encode(val), do: {val, %{}}

  # List traversal
  defp do_encode_list(list) do
    list
    |> Enum.with_index()
    |> Enum.reduce({[], %{}}, fn {v, index}, {acc_json, acc_meta} ->
      {v_json, v_meta} = do_encode(v)
      acc_json = [v_json | acc_json]
      acc_meta = merge_meta(acc_meta, [index], v_meta)
      {acc_json, acc_meta}
    end)
    |> (fn {json_list, meta} -> {Enum.reverse(json_list), meta} end).()
  end

  # Plain map traversal
  defp do_encode_map(map) do
    Enum.reduce(map, {%{}, %{}}, fn {k, v}, {acc_json, acc_meta} ->
      str_k = to_string(k)
      {v_json, v_meta} = do_encode(v)
      acc_json = Map.put(acc_json, str_k, v_json)
      acc_meta = merge_meta(acc_meta, [str_k], v_meta)
      {acc_json, acc_meta}
    end)
  end

  # JS Map traversal
  defp do_encode_js_map(map) do
    {json_entries, meta} =
      map
      |> Enum.to_list()
      |> Enum.with_index()
      |> Enum.reduce({[], %{}}, fn {{k, v}, index}, {acc_json, acc_meta} ->
        {k_json, k_meta} = do_encode(k)
        {v_json, v_meta} = do_encode(v)

        acc_meta =
          acc_meta
          |> merge_meta([index, 0], k_meta)
          |> merge_meta([index, 1], v_meta)

        acc_json = [[k_json, v_json] | acc_json]
        {acc_json, acc_meta}
      end)

    json_entries = Enum.reverse(json_entries)

    if map_size(meta) > 0 do
      {json_entries, ["map", meta]}
    else
      {json_entries, ["map"]}
    end
  end

  # Meta merging logic
  defp merge_meta(acc, _path, meta) when is_map(meta) and map_size(meta) == 0, do: acc

  defp merge_meta(acc, path, meta) when is_list(meta) do
    Map.put(acc, Path.stringify(path), meta)
  end

  defp merge_meta(acc, path, meta) when is_map(meta) do
    prefix = Path.stringify(path)

    new_meta =
      Enum.reduce(meta, %{}, fn {k, v}, nested_acc ->
        Map.put(nested_acc, prefix <> "." <> k, v)
      end)

    Map.merge(acc, new_meta)
  end

  # --- DECODE ---

  @doc """
  Decodes a SuperJSON payload (a map or raw JSON binary string).
  """
  @spec decode(map() | binary()) :: {:ok, term()} | {:error, term()}
  def decode(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, decoded} -> {:ok, decode_map(decoded)}
      {:error, _} = err -> err
    end
  end

  def decode(payload) when is_map(payload) do
    {:ok, decode_map(payload)}
  end

  def decode(payload), do: {:ok, payload}

  @doc """
  Decodes a SuperJSON payload or raises an error if binary JSON parsing fails.
  """
  @spec decode!(map() | binary()) :: term()
  def decode!(payload) when is_binary(payload) do
    payload
    |> Jason.decode!()
    |> decode_map()
  end

  def decode!(payload) when is_map(payload) do
    decode_map(payload)
  end

  def decode!(payload), do: payload

  defp decode_map(%{"json" => json, "meta" => meta}) when is_map(meta) do
    json
    |> hydrate_referential_equalities(Map.get(meta, "referentialEqualities"))
    |> hydrate_values(Map.get(meta, "values"))
  end

  defp decode_map(%{"json" => json} = payload) when map_size(payload) == 1 do
    json
  end

  defp decode_map(payload), do: payload

  defp hydrate_referential_equalities(json, ref_eq) when is_map(ref_eq) or is_list(ref_eq) do
    Enum.reduce(ref_eq, json, fn item, acc ->
      {target_str, source_list} =
        case item do
          {t, s} when is_list(s) -> {t, s}
          [t, s | _] when is_list(s) -> {t, s}
          [t, s | _] -> {t, [s]}
          _ -> {nil, nil}
        end

      case {target_str, source_list} do
        {target_str, [source_str | _]} when is_binary(target_str) and is_binary(source_str) ->
          source_path = Path.parse(source_str)
          target_path = Path.parse(target_str)

          try do
            case get_in(acc, source_path) do
              nil -> acc
              val -> put_in_deep(acc, target_path, val)
            end
          rescue
            _ -> acc
          end

        _ ->
          acc
      end
    end)
  end

  defp hydrate_referential_equalities(json, _), do: json

  defp hydrate_values(json, values) when is_map(values) do
    sorted_paths =
      values
      |> Enum.map(fn {path_str, types} -> {Path.parse(path_str), types} end)
      |> Enum.sort_by(fn {path, _} -> length(path) end, :desc)

    Enum.reduce(sorted_paths, json, fn {path, types_list}, acc ->
      hydrate_value_at_path(acc, path, types_list)
    end)
  end

  defp hydrate_values(json, values) when is_list(values) do
    apply_type(json, values)
  end

  defp hydrate_values(json, _), do: json

  defp hydrate_value_at_path(acc, path, types_list) do
    try do
      case get_in(acc, path) do
        nil ->
          acc

        val ->
          new_val = apply_type(val, types_list)
          put_in_deep(acc, path, new_val)
      end
    rescue
      _ -> acc
    end
  end

  defp apply_type(val, ["Date" | _]) when is_binary(val) do
    case DateTime.from_iso8601(val) do
      {:ok, dt, _} -> dt
      _ -> val
    end
  end

  defp apply_type(val, ["bigint" | _]) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> val
    end
  end

  defp apply_type(val, ["regexp" | _]) when is_binary(val) do
    case Regex.run(~r/^\/(.*)\/([a-z]*)$/, val) do
      [_, pattern, flags] ->
        elixir_flags =
          flags
          |> String.graphemes()
          |> Enum.filter(&(&1 in ["i", "m", "s", "u", "x"]))
          |> Enum.join("")

        case Regex.compile(pattern, elixir_flags) do
          {:ok, regex} -> regex
          _ -> val
        end

      _ ->
        val
    end
  end

  defp apply_type(val, ["URL" | _]) when is_binary(val) do
    URI.parse(val)
  end

  defp apply_type(val, ["Error" | _]) when is_map(val) do
    %RuntimeError{message: val["message"] || ""}
  end

  defp apply_type(_val, ["undefined" | _]) do
    nil
  end

  defp apply_type(val, ["number" | _]) do
    case val do
      "NaN" -> :nan
      "Infinity" -> :inf
      "-Infinity" -> :"-inf"
      _ -> val
    end
  end

  defp apply_type(val, ["set", nested_annotations])
       when is_list(val) and is_map(nested_annotations) do
    hydrated_list = hydrate_values(val, nested_annotations)
    MapSet.new(hydrated_list)
  end

  defp apply_type(val, ["set" | _]) when is_list(val) do
    MapSet.new(val)
  end

  defp apply_type(val, ["map", nested_annotations])
       when is_list(val) and is_map(nested_annotations) do
    hydrated_list = hydrate_values(val, nested_annotations)

    Map.new(hydrated_list, fn
      [k, v] -> {k, v}
      other -> {other, nil}
    end)
  end

  defp apply_type(val, ["map" | _]) when is_list(val) do
    Map.new(val, fn
      [k, v] -> {k, v}
      other -> {other, nil}
    end)
  end

  defp apply_type(val, _), do: val

  defp put_in_deep(_data, [], val), do: val

  defp put_in_deep(data, [key | rest], val) do
    case key do
      key when is_binary(key) or is_atom(key) ->
        data = if is_map(data), do: data, else: %{}
        child = Map.get(data, key)
        Map.put(data, key, put_in_deep(child, rest, val))

      _ ->
        put_in(data, [key | rest], val)
    end
  end
end
