defmodule WarungWeb.OrderParamsTest do
  use ExUnit.Case, async: true

  alias WarungWeb.OrderParams

  describe "status_label/1" do
    test "labels a nil status" do
      assert OrderParams.status_label(nil) == "unknown"
    end

    test "stringifies a present status" do
      assert OrderParams.status_label(:placed) == "placed"
      assert OrderParams.status_label("shipped") == "shipped"
    end
  end

  describe "display_name/1" do
    test "upcases a present name" do
      assert OrderParams.display_name(%{name: "budi"}) == "BUDI"
    end

    test "falls back to ANONYMOUS when there is no usable name" do
      assert OrderParams.display_name(%{name: nil}) == "ANONYMOUS"
      assert OrderParams.display_name(%{}) == "ANONYMOUS"
    end

    test "falls back to ANONYMOUS on a non-binary name" do
      assert OrderParams.display_name(%{name: 42}) == "ANONYMOUS"
    end
  end

  describe "timeout_for/1" do
    test "returns the timeout when present" do
      assert OrderParams.timeout_for(%{timeout: 9_000}) == 9_000
    end

    test "returns the default when absent" do
      assert OrderParams.timeout_for(%{}) == 5_000
    end
  end

  describe "third_field/1" do
    test "returns the third element when the tuple has one" do
      assert OrderParams.third_field({:a, :b, :c}) == :c
    end

    test "returns the third element when the tuple has more than three" do
      assert OrderParams.third_field({:a, :b, :c, :d}) == :c
    end

    test "handles a tuple with fewer than three elements" do
      assert OrderParams.third_field({:a, :b}) == nil
    end
  end

  describe "currency_from/1" do
    test "reads the currency from an object payload" do
      assert OrderParams.currency_from(~s({"currency":"IDR"})) == "IDR"
    end

    test "returns an error tuple for a list payload rather than raising" do
      assert OrderParams.currency_from(~s([1,2,3])) == {:error, :not_an_object}
    end

    test "returns an error tuple for a bare JSON scalar rather than raising" do
      assert OrderParams.currency_from("42") == {:error, :not_an_object}
    end

    test "returns an error tuple when the key is missing" do
      assert OrderParams.currency_from(~s({"amount":10})) == {:error, :missing_currency}
    end
  end
end
