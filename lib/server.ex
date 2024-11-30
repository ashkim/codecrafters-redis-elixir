defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application

  def start(_type, _args) do
    children = [
      # start repo first
      Repo,
      # start the TCP listener
      {Task, fn -> Server.listen() end}
    ]

    opts = [strategy: :one_for_one, name: Server.Supervisor]

    Supervisor.start_link(children, opts)
  end

  @doc """
  Listen for incoming connections
  """
  def listen() do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    # Uncomment this block to pass the first stage
    #
    # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # ensures that we don't run into 'Address already in use' errors
    {:ok, socket} = :gen_tcp.listen(6379, [:binary, active: false, reuseaddr: true])

    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Task.async(fn -> serve(client) end)
    loop_acceptor(socket)
  end

  defp serve(client) do
    case :gen_tcp.recv(client, 0) do
      {:ok, data} ->
        Command.process(client, data)
        serve(client)

      {:error, :closed} ->
        :gen_tcp.close(client)

      {:error, :timeout} ->
        Logger.error("Timeout error did not recieve message")
    end
  end
end
