# Namespaced under `Holdout` on purpose. A model that solves this task and
# then writes the canonically-named test for the module it was told to fix
# — `test/warung_web/order_params_test.exs`, `WarungWeb.OrderParamsTest` —
# used to collide with this file when `grade` copied it in, and the whole run
# failed to compile. That scored `completed=no` for a model that did the task
# and then did the diligent thing. The module name and the filename both carry
# the prefix so neither can clash.
defmodule WarungWeb.Holdout.OrderParamsTest do
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
