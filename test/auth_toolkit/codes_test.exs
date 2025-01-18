defmodule IntegerEncoderTest do
  use ExUnit.Case

  alias AuthToolkit.Codes

  describe "encode_integer/1" do
    test "encodes 0 as a string with 6 characters from the first alphabet character" do
      assert Codes.encode_integer(0) == "BBBBBB"
    end

    test "encodes the maximum integer correctly" do
      assert Codes.encode_integer(Codes.max_integer()) == "999999"
    end

    test "encodes a valid integer within the limit" do
      assert Codes.encode_integer(100) == "BBBBGM"
    end

    test "returns an error for an integer that exceeds the maximum limit" do
      assert Codes.encode_integer(Codes.max_integer() + 1) ==
               {:error, "The input integer is too large to be encoded in 6 characters"}
    end
  end

  describe "random_code/0" do
    test "returns a string with 6 characters from the alphabet" do
      assert String.length(Codes.random_code()) == 6
    end

    test "returns a string with characters from the alphabet" do
      assert Codes.random_code() =~ ~r/^[BCDFGHJKMPQRTVWXY346789]+$/
    end
  end
end
