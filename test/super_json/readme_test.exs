defmodule SuperJSON.ReadmeTest do
  use ExUnit.Case, async: true
  alias SuperJSON

  describe "README examples" do
    test "decoding example" do
      json_string = """
      {
        "json": {
          "createdAt": "2023-10-10T15:20:00Z",
          "amount": "9007199254740991",
          "pattern": "/abc/i"
        },
        "meta": {
          "values": {
            "createdAt": ["Date"],
            "amount": ["bigint"],
            "pattern": ["regexp"]
          }
        }
      }
      """

      {:ok, result} = SuperJSON.decode(json_string)

      assert result["createdAt"] == ~U[2023-10-10 15:20:00Z]
      assert result["amount"] == 9007199254740991
      assert result["pattern"] == ~r/abc/i
    end

    test "encoding example" do
      my_data = %{
        "date" => ~U[2026-01-01 12:00:00Z],
        "set" => MapSet.new([1, 2, :nan]),
        "url" => URI.parse("https://www.example.com")
      }

      encoded = SuperJSON.encode(my_data)

      assert encoded == %{
        "json" => %{
          "date" => "2026-01-01T12:00:00Z",
          "set" => [1, 2, "NaN"],
          "url" => "https://www.example.com"
        },
        "meta" => %{
          "values" => %{
            "date" => ["Date"],
            "set" => ["set", %{"2" => ["number"]}],
            "url" => ["URL"]
          }
        }
      }
    end
  end
end
