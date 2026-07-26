defmodule SuperJSONTest do
  use ExUnit.Case, async: true

  alias SuperJSON

  describe "decode/1 & encode/1 (Mirror of core TS cases)" do
    test "works for objects" do
      input = %{"a" => %{"1" => 5, "2" => %{"3" => "c"}}, "b" => nil}
      encoded = SuperJSON.encode(input)

      assert encoded == %{"json" => input}
      assert SuperJSON.decode!(encoded) == input
    end

    test "special case: objects with array-like keys" do
      input = %{"a" => %{"0" => 3, "1" => 5, "2" => %{"3" => "c"}}, "b" => nil}
      encoded = SuperJSON.encode(input)
      
      assert encoded == %{"json" => input}
      assert SuperJSON.decode!(encoded) == input
    end

    test "works for arrays" do
      input = %{"a" => [1, nil, 2]}
      encoded = SuperJSON.encode(input)

      assert encoded == %{"json" => input}
      assert SuperJSON.decode!(encoded) == input
    end

    test "works for Sets" do
      input = %{"a" => MapSet.new([1, nil, 2])}
      encoded = SuperJSON.encode(input)

      assert encoded["meta"] == %{"values" => %{"a" => ["set"]}}
      assert Enum.sort(encoded["json"]["a"]) == [1, 2, nil]

      assert SuperJSON.decode!(encoded) == input
    end

    test "works for top-level Sets" do
      input = MapSet.new([1, nil, 2])
      encoded = SuperJSON.encode(input)

      assert encoded["meta"] == %{"values" => ["set"]}
      assert Enum.sort(encoded["json"]) == [1, 2, nil]

      assert SuperJSON.decode!(encoded) == input
    end

    test "works for Maps" do
      input = %{"a" => Map.new([{1, "a"}, {:nan, "b"}])}
      encoded = SuperJSON.encode(input)

      assert encoded == %{
               "json" => %{"a" => [[1, "a"], ["NaN", "b"]]},
               "meta" => %{
                 "values" => %{
                   "a" => ["map", %{"1.0" => ["number"]}]
                 }
               }
             }

      assert SuperJSON.decode!(encoded) == input
    end

    test "works for dates" do
      input = %{"createdAt" => ~U[2023-10-10 15:20:00Z]}
      encoded = SuperJSON.encode(input)

      assert encoded == %{
               "json" => %{"createdAt" => "2023-10-10T15:20:00Z"},
               "meta" => %{"values" => %{"createdAt" => ["Date"]}}
             }

      assert SuperJSON.decode!(encoded) == input
    end

    test "works for regex" do
      input = %{"pattern" => ~r/abc/i}
      encoded = SuperJSON.encode(input)

      assert encoded == %{
               "json" => %{"pattern" => "/abc/i"},
               "meta" => %{"values" => %{"pattern" => ["regexp"]}}
             }

      assert SuperJSON.decode!(encoded) == input
    end

    test "works for bigint" do
      input = %{"amount" => 9_007_199_254_740_992}
      encoded = SuperJSON.encode(input)

      assert encoded == %{
               "json" => %{"amount" => "9007199254740992"},
               "meta" => %{"values" => %{"amount" => ["bigint"]}}
             }

      assert SuperJSON.decode!(encoded) == input
    end

    test "works for URL" do
      input = URI.parse("https://example.com")
      encoded = SuperJSON.encode(input)

      assert encoded == %{
               "json" => "https://example.com",
               "meta" => %{"values" => ["URL"]}
             }

      assert SuperJSON.decode!(encoded) == input
    end

    test "works for Errors" do
      input = %RuntimeError{message: "something went wrong"}
      encoded = SuperJSON.encode(input)

      assert encoded == %{
               "json" => %{"name" => "Error", "message" => "something went wrong"},
               "meta" => %{"values" => ["Error"]}
             }

      assert SuperJSON.decode!(encoded) == input
    end

    test "works for NaN" do
      input = %{"amount" => :nan}
      encoded = SuperJSON.encode(input)

      assert encoded == %{
        "json" => %{"amount" => "NaN"},
        "meta" => %{"values" => %{"amount" => ["number"]}}
      }
      assert SuperJSON.decode!(encoded) == input
    end

    test "works for Infinity" do
      input = %{"amount" => :inf}
      encoded = SuperJSON.encode(input)

      assert encoded == %{
        "json" => %{"amount" => "Infinity"},
        "meta" => %{"values" => %{"amount" => ["number"]}}
      }
      assert SuperJSON.decode!(encoded) == input
    end

    test "works for -Infinity" do
      input = %{"amount" => :"-inf"}
      encoded = SuperJSON.encode(input)

      assert encoded == %{
        "json" => %{"amount" => "-Infinity"},
        "meta" => %{"values" => %{"amount" => ["number"]}}
      }
      assert SuperJSON.decode!(encoded) == input
    end

    test "hydrates Sets and Maps with nested annotations" do
      input = %{
        "mySet" => MapSet.new([1, ~U[2023-10-10 15:20:00Z]]),
        "myMap" =>
          Map.new([
            {1, "a"},
            {~U[2023-11-11 12:00:00Z], "b"}
          ])
      }

      encoded = SuperJSON.encode(input)

      assert encoded == %{
               "json" => %{
                 "mySet" => [1, "2023-10-10T15:20:00Z"],
                 "myMap" => [
                   [1, "a"],
                   ["2023-11-11T12:00:00Z", "b"]
                 ]
               },
               "meta" => %{
                 "values" => %{
                   "mySet" => ["set", %{"1" => ["Date"]}],
                   "myMap" => ["map", %{"1.0" => ["Date"]}]
                 }
               }
             }

      assert SuperJSON.decode!(encoded) == input
    end

    test "works for paths containing dots" do
      input = %{
        "a.1" => %{
          "b" => MapSet.new([1, 2])
        }
      }

      encoded = SuperJSON.encode(input)

      assert encoded == %{
               "json" => %{
                 "a.1" => %{
                   "b" => [1, 2]
                 }
               },
               "meta" => %{
                 "values" => %{
                   "a\\.1.b" => ["set"]
                 }
               }
             }

      assert SuperJSON.decode!(encoded) == input
    end

    test "works for paths containing backslashes" do
      input = %{
        "a\\.1" => %{
          "b" => MapSet.new([1, 2])
        }
      }

      encoded = SuperJSON.encode(input)

      assert encoded == %{
               "json" => %{
                 "a\\.1" => %{
                   "b" => [1, 2]
                 }
               },
               "meta" => %{
                 "values" => %{
                   "a\\\\\\.1.b" => ["set"]
                 }
               }
             }

      assert SuperJSON.decode!(encoded) == input
    end
  end

  describe "decode/1 special cases" do
    test "decodes binary raw JSON string" do
      json_str = """
      {
        "json": {
          "timestamp": "2026-07-26T12:00:00Z"
        },
        "meta": {
          "values": {
            "timestamp": ["Date"]
          }
        }
      }
      """

      {:ok, result} = SuperJSON.decode(json_str)
      assert %DateTime{} = result["timestamp"]
    end

    test "returns error tuple on invalid JSON binary" do
      assert {:error, %Jason.DecodeError{}} = SuperJSON.decode("{invalid json")

      assert_raise Jason.DecodeError, fn ->
        SuperJSON.decode!("{invalid json")
      end
    end

    test "safely ignores invalid Date strings or undefined" do
      payload = %{
        "json" => %{"nothing" => nil, "badDate" => "hello"},
        "meta" => %{
          "values" => %{
            "some.missing.path" => ["undefined"],
            "badDate" => ["Date"]
          }
        }
      }

      {:ok, result} = SuperJSON.decode(payload)
      assert result["badDate"] == "hello"
      assert Map.get(result, "some") == nil
    end
  end

  describe "referential equalities" do
    # Encoding doesn't attempt deduplication (which matches TS dedupe:false default)
    # But decoding should flawlessly handle referential equalities generated by TS backend.

    test "hydrates referential equalities" do
      payload = %{
        "json" => %{
          "sources" => %{},
          "debug" => %{
            "rawOutput" => %{
              "urls" => ["http://example.com"]
            }
          }
        },
        "meta" => %{
          "referentialEqualities" => %{
            "sources.urls" => ["debug.rawOutput.urls"]
          }
        }
      }

      {:ok, result} = SuperJSON.decode(payload)
      assert result["sources"]["urls"] == ["http://example.com"]
    end

    test "hydrates referential equalities involving arrays" do
      payload = %{
        "json" => %{
          "data" => [
            %{"id" => 1},
            %{"id" => 2}
          ],
          "lookups" => [nil, nil]
        },
        "meta" => %{
          "referentialEqualities" => %{
            "lookups.0" => ["data.0"],
            "lookups.1" => ["data.1"]
          }
        }
      }

      {:ok, result} = SuperJSON.decode(payload)
      assert Enum.at(result["lookups"], 0) == %{"id" => 1}
      assert Enum.at(result["lookups"], 1) == %{"id" => 2}
    end
  end
end
