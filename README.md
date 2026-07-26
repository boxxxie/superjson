# SuperJSON for Elixir

[![Hex.pm](https://img.shields.io/hexpm/v/superjson.svg)](https://hex.pm/packages/superjson)
[![Documentation](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/superjson)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A high-fidelity **SuperJSON** decoder and encoder for Elixir. Seamlessly serialize and rehydrate JavaScript/TypeScript complex types (Dates, MapSets, Maps, BigInts, Regexps, URLs, Errors, and referential equalities) into native Elixir data structures. 

Perfect for communicating with JS/TS frameworks that use SuperJSON for payload serialization, such as **Trigger.dev**, **tRPC**, **Remix**, **Blitz.js**, or **Next.js**.

## Installation

Add `superjson` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:superjson, "~> 0.1.0"}
  ]
end
```

## Features

- **Bidirectional**: Full support for both decoding (JS -> Elixir) and encoding (Elixir -> JS).
- **DateTime / Date**: Converts ISO8601 string fields back to `%DateTime{}` and vice-versa.
- **BigInt Support**: Parses stringified BigInts into native Elixir integers, and encodes large Elixir integers as `bigint`.
- **RegExp Support**: Converts JavaScript regex strings (`/pattern/flags`) into native `%Regex{}` structs.
- **Sets and Maps**: Rehydrates JavaScript `Set` into `MapSet` and JavaScript `Map` into standard Elixir `Map`. Nested value annotations are rigorously supported!
- **URLs & Errors**: Maps JS `URL` objects to `%URI{}`, and JS `Error` objects to `%RuntimeError{}`.
- **Special Numbers**: Gracefully handles JS `NaN`, `Infinity`, and `-Infinity` by mapping them to Elixir atoms (`:nan`, `:inf`, `:"-inf"`).
- **Referential Equalities**: Resolves structural references and shared object identity paths on decoding to perfectly restore graph structures.
- **Path Escaping**: Implements the official SuperJSON path stringification and parsing specifications (handling escaped dots `\\.` and backslashes `\\\\`).

## Usage

### Decoding (JS -> Elixir)

You can pass a raw JSON string or a pre-parsed map (via `Jason`).

```elixir
payload = %{
  "json" => %{
    "createdAt" => "2023-10-10T15:20:00Z",
    "amount" => "9007199254740991",
    "pattern" => "/abc/i"
  },
  "meta" => %{
    "values" => %{
      "createdAt" => ["Date"],
      "amount" => ["bigint"],
      "pattern" => ["regexp"]
    }
  }
}

{:ok, result} = SuperJSON.decode(payload)
# Or raise on error:
# result = SuperJSON.decode!(payload)

# result["createdAt"] => ~U[2023-10-10 15:20:00Z]
# result["amount"]    => 9007199254740991
# result["pattern"]   => ~r/abc/i
```

### Encoding (Elixir -> JS)

Pass native Elixir structs, MapSets, and atoms, and get a SuperJSON payload ready to be sent to a JavaScript client.

```elixir
my_data = %{
  "date" => ~U[2026-01-01 12:00:00Z],
  "set" => MapSet.new([1, 2, :nan]),
  "url" => URI.parse("https://github.com/boxxxie/superjson")
}

encoded = SuperJSON.encode(my_data)
# %{
#   "json" => %{
#     "date" => "2026-01-01T12:00:00Z",
#     "set" => [1, 2, "NaN"],
#     "url" => "https://github.com/boxxxie/superjson"
#   },
#   "meta" => %{
#     "values" => %{
#       "date" => ["Date"],
#       "set" => ["set", %{"2" => ["number"]}],
#       "url" => ["URL"]
#     }
#   }
# }

# You can also use `SuperJSON.encode!/1` to return a raw JSON string directly:
# json_string = SuperJSON.encode!(my_data)
```

## License

This package is licensed under the [MIT License](LICENSE).
