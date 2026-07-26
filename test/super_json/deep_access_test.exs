defmodule SuperJSON.DeepAccessTest do
  use ExUnit.Case, async: true
  alias SuperJSON

  describe "deep access and mutation via decode" do
    test "correctly sets values in nested Maps and Sets" do
      # In Elixir, we don't have a mutable `setDeep` utility like JS because data is immutable.
      # However, we test the exact equivalent of `accessDeep.test.ts` by ensuring our
      # decoder correctly traverses deeply nested structures defined by paths, identical
      # to how `setDeep` is used during TS SuperJSON's hydration phase.

      # Equivalent to: a: new Map([[new Set(['NaN']), [[1, 'undefined']]]])
      # Where ['NaN'] becomes NaN and 'undefined' becomes undefined (nil in Elixir)
      # and the inner array becomes a Map.

      payload = %{
        "json" => %{
          "a" => [
            [
              ["NaN"], # the Set elements array
              [[1, "undefined"]] # the Map entries array
            ]
          ]
        },
        "meta" => %{
          "values" => %{
            "a" => ["map"],
            "a.0.0" => ["set"],
            "a.0.0.0" => ["number"],
            "a.0.1" => ["map"],
            "a.0.1.0.1" => ["undefined"]
          }
        }
      }

      {:ok, result} = SuperJSON.decode(payload)

      # Reconstruct the expected output
      expected_inner_map = %{1 => nil}
      expected_key_set = MapSet.new([:nan])
      expected_outer_map = %{expected_key_set => expected_inner_map}

      assert result["a"] == expected_outer_map
    end

    test "correctly sets values in nested sets" do
      # Equivalent to: a: new Set([10, new Set(['NaN'])]) -> a: new Set([10, new Set([NaN])])
      payload = %{
        "json" => %{
          "a" => [10, ["NaN"]]
        },
        "meta" => %{
          "values" => %{
            "a" => ["set"],
            "a.1" => ["set"],
            "a.1.0" => ["number"]
          }
        }
      }

      {:ok, result} = SuperJSON.decode(payload)

      expected_inner_set = MapSet.new([:nan])
      expected_outer_set = MapSet.new([10, expected_inner_set])

      assert result["a"] == expected_outer_set
    end
  end
end
