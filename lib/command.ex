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

  defp send_command(client, [command | [key, value | other]]) when command in ~w(SET set) do
    Logger.info("SET command received with #{inspect([key, value | other])}")

    with {:ok, opts} <- Repo.SetOptions.parse_set_options(other),
         {:ok, opts} <- Repo.SetOptions.validate(opts),
         :ok <- Repo.set(key, value, opts) do
      message = CommandEncode.encode_simple_string("OK")
      :gen_tcp.send(client, message)
    else
      {:error, reason} ->
        message = CommandEncode.encode_error("ERR #{reason}")
        :gen_tcp.send(client, message)
    end
  end

  defp send_command(client, [command | _rest]) when command in ~w(SET set) do
    message = CommandEncode.encode_error("ERR wrong number of arguments for SET command")
    :gen_tcp.send(client, message)
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
