defmodule AuthToolkit.Codes do
  @moduledoc false
  # An alphabet that generates words that are likely free of offensive words
  @alphabet "BCDFGHJKMPQRTVWXY346789"
  @base String.length(@alphabet)
  @max_length 6
  @max_integer trunc(:math.pow(@base, @max_length) - 1)

  def max_integer, do: @max_integer

  def random_code do
    encode_integer(:rand.uniform(@max_integer))
  end

  def encode_integer(integer) when is_integer(integer) and integer >= 0 and integer <= @max_integer do
    if integer == 0 do
      String.duplicate(String.at(@alphabet, 0), @max_length)
    else
      encoded = encode_integer_recursive(integer, "")
      String.pad_leading(encoded, @max_length, String.at(@alphabet, 0))
    end
  end

  def encode_integer(integer) when is_integer(integer) and integer > @max_integer do
    {:error, "The input integer is too large to be encoded in #{@max_length} characters"}
  end

  defp encode_integer_recursive(integer, acc) do
    case div_rem(integer, @base) do
      {0, remainder} ->
        String.at(@alphabet, remainder) <> acc

      {quotient, remainder} ->
        encoded_remainder = String.at(@alphabet, remainder)
        encode_integer_recursive(quotient, encoded_remainder <> acc)
    end
  end

  defp div_rem(integer, base) do
    {div(integer, base), rem(integer, base)}
  end
end
