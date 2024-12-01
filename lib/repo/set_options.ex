defmodule Repo.SetOptions do
  defstruct [
    :expire_in_seconds,
    :expire_in_ms,
    :expire_at_timestamp,
    :expire_at_timestamp_ms,
    only_if_exists: false,
    only_if_not_exists: false,
    keep_ttl: false,
    return_old: false
  ]

  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  def parse_set_options(args), do: parse_set_options(args, new())

  def parse_set_options([], acc), do: {:ok, acc}

  def parse_set_options([cmd, value | rest], acc) when cmd in ~w(PX px) do
    with {ms, ""} <- Integer.parse(value) do
      parse_set_options(rest, %{acc | expire_in_ms: ms})
    else
      _ -> {:error, "Invalid PX value"}
    end
  end

  def parse_set_options([cmd, value | rest], acc) when cmd in ~w(EX ex) do
    with {seconds, ""} <- Integer.parse(value) do
      parse_set_options(rest, %{acc | expire_in_seconds: seconds})
    else
      _ -> {:error, "Invalid EX value"}
    end
  end

  def parse_set_options([cmd, value | rest], acc) when cmd in ~w(PXAT pxat) do
    with {ms, ""} <- Integer.parse(value) do
      parse_set_options(rest, %{acc | expire_at_timestamp_ms: ms})
    else
      _ -> {:error, "Invalid PXAT value"}
    end
  end

  def parse_set_options([cmd, value | rest], acc) when cmd in ~w(EXAT exat) do
    with {seconds, ""} <- Integer.parse(value) do
      parse_set_options(rest, %{acc | expire_at_timestamp: seconds})
    else
      _ -> {:error, "Invalid EXAT value"}
    end
  end

  def parse_set_options([cmd | rest], acc) when cmd in ~w(XX xx) do
    parse_set_options(rest, %{acc | only_if_exists: true})
  end

  def parse_set_options([cmd | rest], acc) when cmd in ~w(NX nx) do
    parse_set_options(rest, %{acc | only_if_not_exists: true})
  end

  def parse_set_options([cmd | rest], acc) when cmd in ~w(KEEPTTL keepttl) do
    parse_set_options(rest, %{acc | keep_ttl: true})
  end

  def parse_set_options([cmd | rest], acc) when cmd in ~w(GET get) do
    parse_set_options(rest, %{acc | return_old: true})
  end

  # Handle missing values for options that require them
  def parse_set_options([opt | _], _acc) when opt in ["PX", "EX", "PXAT", "EXAT"] do
    {:error, "Missing value for #{opt}"}
  end

  # Handle unknown options
  def parse_set_options([unknown | _], _acc) do
    {:error, "Unknown option: #{unknown}"}
  end

  # Add validation for conflicting options
  def validate(opts) do
    cond do
      opts.only_if_exists and opts.only_if_not_exists ->
        {:error, "Cannot combine XX and NX options"}

      has_multiple_expire_options?(opts) ->
        {:error, "Cannot combine multiple expire options"}

      true ->
        {:ok, opts}
    end
  end

  defp has_multiple_expire_options?(opts) do
    [
      opts.expire_in_seconds,
      opts.expire_in_ms,
      opts.expire_at_timestamp,
      opts.expire_at_timestamp_ms
    ]
    |> Enum.count(&(&1 != nil)) > 1
  end
end
