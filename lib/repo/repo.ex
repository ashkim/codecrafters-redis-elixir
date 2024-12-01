defmodule Repo do
  use GenServer

  def init(_) do
    {:ok, %{data: %{}, expiry_timers: %{}}}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(_opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      %{
        data: %{},
        expiry_timers: %{}
      },
      name: __MODULE__
    )
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def set(key, value, %Repo.SetOptions{} = opts) do
    GenServer.cast(__MODULE__, {:set, key, value, opts})
  end

  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state.data, key), state}
  end

  def handle_info({:expire, key}, state) do
    new_state =
      state
      |> update_in([:data], &Map.delete(&1, key))
      |> update_in([:expiry_timers], &Map.delete(&1, key))

    {:noreply, new_state}
  end

  def handle_cast({:set, key, value, opts}, state) do
    timer_ref = setup_expiry_timer(key, opts)

    new_state =
      state
      |> cancel_existing_timer(key)
      |> put_in([:data, key], value)
      |> put_in([:expiry_timers, key], timer_ref)

    {:noreply, new_state}
  end

  defp setup_expiry_timer(key, %{expire_in_seconds: seconds}) when not is_nil(seconds) do
    Process.send_after(self(), {:expire, key}, seconds * 1000)
  end

  defp setup_expiry_timer(key, %{expire_in_ms: ms}) when not is_nil(ms) do
    Process.send_after(self(), {:expire, key}, ms)
  end

  defp setup_expiry_timer(key, %{expire_at_timestamp_ms: ts_ms}) when not is_nil(ts_ms) do
    now = System.system_time(:millisecond)

    if ts_ms > now do
      Process.send_after(self(), {:expire, key}, ts_ms - now)
    end
  end

  defp setup_expiry_timer(_key, _opts), do: nil

  defp cancel_existing_timer(state, key) do
    case Map.get(state.expiry_timers, key) do
      nil ->
        state

      timer_ref ->
        Process.cancel_timer(timer_ref)
        update_in(state, [:expiry_timers], &Map.delete(&1, key))
    end
  end

  def handle_cast({:delete, key}, state) do
    # cancel any prior timers for this key
    case Map.get(state.expiry_timers, key) do
      nil -> :ok
      timer_ref -> Process.cancel_timer(timer_ref)
    end

    {:noreply, Map.delete(state.data, key)}
  end
end
