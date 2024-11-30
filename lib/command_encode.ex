defmodule CommandEncode do
  @crlf "\r\n"

  def encode_simple_string(data) do
    "+#{data}#{@crlf}"
  end

  def encode_error(data) do
    "-#{data}#{@crlf}"
  end

  def encode_integer(data) do
    ":#{data}#{@crlf}"
  end

  def encode_bulk_string(data) do
    "$#{String.length(data)}#{@crlf}#{data}#{@crlf}"
  end
end
