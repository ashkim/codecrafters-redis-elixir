defmodule CommandDecode do
  @moduledoc """
  Implements RESP (Redis Serialization Protocol) decoder.
  Supported types:
  - Simple Strings ("+")
  - Errors ("-")
  - Integers (":")
  - Bulk Strings ("$")
  - Arrays ("*")
  """

  @crlf "\r\n"

  def decode(value) do
    do_decode(value)
  end

  defp do_decode(<<"+", rest::binary>>), do: decode_string(rest)
  defp do_decode(<<"-", rest::binary>>), do: decode_error(rest)
  defp do_decode(<<":", rest::binary>>), do: decode_integer(rest)
  defp do_decode(<<"$", rest::binary>>), do: decode_bulk_string(rest)
  defp do_decode(<<"*", rest::binary>>), do: decode_array(rest)

  defp decode_string(data), do: extract_value_until_crlf(data)

  defp decode_error(data), do: extract_value_until_crlf(data)

  defp decode_integer(<<"+", rest::binary>>), do: parse_unsigned_number(rest)

  defp decode_integer(<<"-", rest::binary>>) do
    with {:ok, acc, rest} <- parse_unsigned_number(rest) do
      {:ok, -acc, rest}
    end
  end

  defp decode_integer(data), do: parse_unsigned_number(data)

  defp decode_array(value) do
    with {:ok, size, rest} <- parse_unsigned_number(value) do
      do_decode_array(size, rest)
    end
  end

  defp decode_bulk_string(<<"0", @crlf, @crlf>>) do
    {:ok, "", ""}
  end

  defp decode_bulk_string(<<"-1", @crlf>>) do
    {:ok, nil, ""}
  end

  defp decode_bulk_string(data) do
    with {:ok, size, rest} <- parse_unsigned_number(data) do
      <<value::binary-size(size), @crlf, other::binary>> = rest
      {:ok, value, other}
    end
  end

  defp do_decode_array(size, data, acc \\ [])

  defp do_decode_array(0, data, acc), do: {:ok, Enum.reverse(acc), data}

  defp do_decode_array(size, data, acc) do
    with {:ok, value, rest} <- do_decode(data) do
      do_decode_array(size - 1, rest, [value | acc])
    end
  end

  defp extract_value_until_crlf(value, acc \\ "")

  defp extract_value_until_crlf(<<@crlf, rest::binary>>, acc) do
    {:ok, acc, rest}
  end

  defp extract_value_until_crlf(<<char::utf8, rest::binary>>, acc) do
    extract_value_until_crlf(rest, <<acc::binary, char::utf8>>)
  end

  defp parse_unsigned_number(data, acc \\ 0)

  defp parse_unsigned_number(<<@crlf, rest::binary>>, acc) do
    {:ok, acc, rest}
  end

  defp parse_unsigned_number(<<byte, rest::binary>>, acc) when byte in ?0..?9 do
    parse_unsigned_number(rest, acc * 10 + byte - ?0)
  end
end
