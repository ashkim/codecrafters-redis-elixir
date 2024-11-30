defmodule Command do
  alias CommandEncode
  require Logger

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

  defp send_command(client, [command | rest]) when command in ~w(SET set) do
    Logger.info("SET command received with #{rest}")

    # split the rest of the command into key and value

    [key, value | _] = rest

    # store the key and value in the repo
    case Repo.set(key, value) do
      :ok ->
        message = CommandEncode.encode_simple_string("OK")
        :gen_tcp.send(client, message)

      _ ->
        message = CommandEncode.encode_error("Error, could not set key")
        :gen_tcp.send(client, message)
    end
  end

  defp send_command(client, [command | rest]) when command in ~w(GET get) do
    Logger.info("GET command received with #{rest}")

    # split the rest of the command into key and value
    [key | _] = rest

    # store the key and value in the repo
    with value <- Repo.get(key) do
      message = CommandEncode.encode_bulk_string(value)
      :gen_tcp.send(client, message)
    else
      _ ->
        message = CommandEncode.encode_error("Error, could not get key")
        :gen_tcp.send(client, message)
    end
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
