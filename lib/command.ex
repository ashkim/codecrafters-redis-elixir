defmodule Command do
  alias CommandEncode

  def process(client, data) do
    with {:ok, command, _rest} <- CommandDecode.decode(data) do
      send_command(client, command)
    end
  end

  defp send_command(client, [command | rest]) when command in ~w(ECHO echo) do
    [value | _] = rest

    message = CommandEncode.encode_bulk_string(value)

    :gen_tcp.send(client, message)
  end

  defp send_command(client, [command | rest]) when command in ~w(PING ping) do
    message = CommandEncode.encode_simple_string("PONG")
    :gen_tcp.send(client, message)
  end

  defp send_command(client, _) do
    message = CommandEncode.encode_error("Error, unknown command")
    :gen_tcp.send(client, message)
  end
end
