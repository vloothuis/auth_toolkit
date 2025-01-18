defmodule AuthToolkit.RateLimiter do
  @moduledoc false
  alias AuthToolkit.RateLimiter.ETS

  @callback check_rate(operation :: String.t(), key :: String.t()) :: {:allow, integer()} | {:deny, integer()}

  def child_spec(_opts) do
    rate_limiter().child_spec([])
  end

  def check_rate(operation, key) do
    rate_limiter().check_rate(operation, key)
  end

  def rate_limiter, do: Application.get_env(:auth_toolkit, :rate_limiter, ETS)
end

defmodule AuthToolkit.RateLimiter.Stub do
  @moduledoc false
  @behaviour AuthToolkit.RateLimiter

  @impl true
  def check_rate(_operation, _key) do
    {:allow, 1}
  end
end

defmodule AuthToolkit.RateLimiter.ETS do
  @moduledoc false
  @behaviour AuthToolkit.RateLimiter

  use GenServer

  @table_name :auth_toolkit_rate_limiter_attempts
  @cleanup_interval :timer.minutes(5)

  @doc false
  def start_table do
    if :ets.whereis(@table_name) == :undefined do
      :ets.new(@table_name, [:named_table, :public, :set])
    end
  end

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    start_table()
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    cleanup_old_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  @impl AuthToolkit.RateLimiter
  def check_rate(operation, key) do
    # Ensure table exists
    start_table()

    {time_window, limit} =
      case operation do
        "register" -> {60_000 * 10, 10}
        "login" -> {60_000 * 5, 5}
        _ -> {60_000 * 10, 10}
      end

    combined_key = "#{operation}:#{key}"
    now = System.system_time(:millisecond)
    cutoff = now - time_window

    current =
      case :ets.lookup(@table_name, combined_key) do
        [{^combined_key, timestamps}] ->
          [now | Enum.filter(timestamps, &(&1 > cutoff))]

        [] ->
          [now]
      end

    :ets.insert(@table_name, {combined_key, current})
    count = length(current)

    if count <= limit do
      {:allow, count}
    else
      {:deny, limit}
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_old_entries do
    now = System.system_time(:millisecond)
    # Use the longest window (10 minutes) as the cutoff
    cutoff = now - 60_000 * 10

    # Match and delete old entries
    :ets.foldl(
      fn {key, timestamps} = _entry, acc ->
        case Enum.filter(timestamps, &(&1 > cutoff)) do
          [] -> :ets.delete(@table_name, key)
          current -> :ets.insert(@table_name, {key, current})
        end

        acc
      end,
      nil,
      @table_name
    )
  end
end
