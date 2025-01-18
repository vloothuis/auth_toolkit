defmodule AuthToolkit.RateLimiterTest do
  use ExUnit.Case, async: false

  import Mock

  alias AuthToolkit.RateLimiter.ETS

  setup do
    # Start fresh ETS table for each test
    ETS.start_link()
    :ok
  end

  describe "ETS rate limiter" do
    test "allows requests within limits" do
      assert {:allow, 1} = ETS.check_rate("login", "test_user")
      assert {:allow, 2} = ETS.check_rate("login", "test_user")
      assert {:allow, 3} = ETS.check_rate("login", "test_user")
      assert {:allow, 4} = ETS.check_rate("login", "test_user")
      assert {:allow, 5} = ETS.check_rate("login", "test_user")
      assert {:deny, 5} = ETS.check_rate("login", "test_user")
    end

    test "handles different users separately" do
      assert {:allow, 1} = ETS.check_rate("login", "user1")
      assert {:allow, 1} = ETS.check_rate("login", "user2")
      assert {:allow, 2} = ETS.check_rate("login", "user1")
      assert {:allow, 2} = ETS.check_rate("login", "user2")
    end

    test "applies different limits for register operation" do
      # Register allows 10 attempts
      Enum.each(1..10, fn i ->
        assert {:allow, ^i} = ETS.check_rate("register", "new_user")
      end)

      assert {:deny, 10} = ETS.check_rate("register", "new_user")
    end

    test "cleans up old entries" do
      # Add some attempts
      ETS.check_rate("login", "test_user")
      ETS.check_rate("login", "test_user")

      # Time travel by changing the system time in the check
      old_now = System.system_time(:millisecond)
      # 6 minutes into future
      future_time = old_now + 60_000 * 6

      # Stub System.system_time/1 for this test
      with_mock System, system_time: fn :millisecond -> future_time end do
        assert {:allow, 1} = ETS.check_rate("login", "test_user")
      end
    end

    test "default operation limits" do
      # Unknown operations default to 10 attempts per 10 minutes
      Enum.each(1..10, fn i ->
        assert {:allow, ^i} = ETS.check_rate("unknown", "test_user")
      end)

      assert {:deny, 10} = ETS.check_rate("unknown", "test_user")
    end
  end

  describe "automatic cleanup" do
    test "automatically removes old entries after cleanup interval" do
      # Add initial entries
      ETS.check_rate("login", "user1")
      ETS.check_rate("login", "user2")

      # Verify entries exist
      assert [{_, timestamps1}] = :ets.lookup(:auth_toolkit_rate_limiter_attempts, "login:user1")
      assert [{_, timestamps2}] = :ets.lookup(:auth_toolkit_rate_limiter_attempts, "login:user2")
      assert length(timestamps1) == 1
      assert length(timestamps2) == 1

      # Simulate time passing (11 minutes)
      future_time = System.system_time(:millisecond) + 60_000 * 11

      # Trigger cleanup manually (simulating automatic cleanup)
      with_mock System, system_time: fn :millisecond -> future_time end do
        send(Process.whereis(ETS), :cleanup)
        # Give the GenServer time to process the message
        Process.sleep(10)

        # Verify entries are removed
        assert :ets.lookup(:auth_toolkit_rate_limiter_attempts, "login:user1") == []
        assert :ets.lookup(:auth_toolkit_rate_limiter_attempts, "login:user2") == []
      end
    end

    test "keeps recent entries during cleanup" do
      now = System.system_time(:millisecond)

      with_mock System,
        system_time: fn :millisecond ->
          # First call returns current time, subsequent calls return future time
          case :erlang.get(:mock_time_called) do
            nil ->
              :erlang.put(:mock_time_called, true)
              now

            _ ->
              # 8 minutes in future (within 10 minute window)
              now + 60_000 * 8
          end
        end do
        # Add initial entry
        ETS.check_rate("login", "test_user")

        # Trigger cleanup
        send(Process.whereis(ETS), :cleanup)
        Process.sleep(10)

        # Verify entry still exists (within time window)
        assert [{_, timestamps}] = :ets.lookup(:auth_toolkit_rate_limiter_attempts, "login:test_user")
        assert length(timestamps) == 1
      end
    end

    test "partially cleans up old timestamps but keeps recent ones" do
      now = System.system_time(:millisecond)

      # Add some attempts with different timestamps
      with_mocks [
        # 12 minutes ago
        {System, [], [system_time: fn :millisecond -> now - 60_000 * 12 end]}
      ] do
        ETS.check_rate("login", "test_user")
      end

      with_mocks [
        # 4 minutes ago
        {System, [], [system_time: fn :millisecond -> now - 60_000 * 4 end]}
      ] do
        ETS.check_rate("login", "test_user")
      end

      # Trigger cleanup at current time
      with_mock System, system_time: fn :millisecond -> now end do
        send(Process.whereis(ETS), :cleanup)
        Process.sleep(10)

        # Verify only recent entry remains
        assert [{_, timestamps}] = :ets.lookup(:auth_toolkit_rate_limiter_attempts, "login:test_user")
        assert length(timestamps) == 1
      end
    end
  end
end
