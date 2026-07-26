defmodule SuperJSON.PathTest do
  use ExUnit.Case, async: true
  alias SuperJSON.Path

  describe "parse/1" do
    test "test.a.b" do
      assert Path.parse("test.a.b") == ["test", "a", "b"]
    end

    test "test\\.a.b" do
      assert Path.parse("test\\.a.b") == ["test.a", "b"]
    end

    test "test\\\\.a.b" do
      # Note: JS backslash escaping `\\\\` resolves to two literal backslashes `\\` in string literal.
      assert Path.parse("test\\\\.a.b") == ["test\\", "a", "b"]
    end

    test "test\\\\a.b" do
      assert Path.parse("test\\\\a.b") == ["test\\a", "b"]
    end

    test "invalid: test\\a.b" do
      assert_raise RuntimeError, ~r/Invalid SuperJSON path/, fn ->
        Path.parse("test\\a.b")
      end
    end

    test "invalid: foo.bar.baz\\" do
      assert_raise RuntimeError, ~r/Invalid SuperJSON path/, fn ->
        Path.parse("foo.bar.baz\\")
      end
    end
  end

  describe "stringify/1 (escapeKey)" do
    test "dontescape" do
      assert Path.stringify(["dontescape"]) == "dontescape"
    end

    test "escape.me" do
      assert Path.stringify(["escape.me"]) == "escape\\.me"
    end
    
    test "multiple parts" do
      assert Path.stringify(["test.a", "b"]) == "test\\.a.b"
      assert Path.stringify(["test\\a", "b"]) == "test\\\\a.b"
    end
  end
end
