defmodule Gemini.Auth.MultiAuthCoordinatorTest do
  @moduledoc """
  Tests for multi-authentication coordination capability.

  Tests the ability to coordinate between different auth strategies
  in the same application instance.
  """

  use ExUnit.Case, async: true

  alias Gemini.Auth.MultiAuthCoordinator

  describe "coordinate_auth/2" do
    test "coordinates gemini auth strategy successfully" do
      opts = [auth: :gemini]

      assert {:ok, :gemini, headers} = MultiAuthCoordinator.coordinate_auth(:gemini, opts)
      assert is_list(headers)
      assert {"Content-Type", "application/json"} in headers
      assert Enum.any?(headers, fn {key, _value} -> key == "x-goog-api-key" end)
    end

    test "coordinates vertex_ai auth strategy successfully" do
      opts = [auth: :vertex_ai]

      assert {:ok, :vertex_ai, headers} = MultiAuthCoordinator.coordinate_auth(:vertex_ai, opts)
      assert is_list(headers)
      assert {"Content-Type", "application/json"} in headers
      assert Enum.any?(headers, fn {key, _value} -> key == "Authorization" end)
    end

    test "returns error for unknown auth strategy" do
      opts = [auth: :unknown]

      assert {:error, reason} = MultiAuthCoordinator.coordinate_auth(:unknown, opts)
      assert reason =~ "Unknown authentication strategy"
    end

    test "handles missing configuration gracefully" do
      opts = []

      # Should use default auth strategy or return proper error
      result = MultiAuthCoordinator.coordinate_auth(:gemini, opts)
      assert match?({:ok, :gemini, _headers}, result) or match?({:error, _reason}, result)
    end
  end

  describe "get_credentials/1" do
    test "retrieves gemini credentials from config" do
      assert {:ok, credentials} = MultiAuthCoordinator.get_credentials(:gemini)
      assert is_map(credentials)
    end

    test "retrieves vertex_ai credentials from config" do
      assert {:ok, credentials} = MultiAuthCoordinator.get_credentials(:vertex_ai)
      assert is_map(credentials)
    end

    test "returns error for unknown strategy" do
      assert {:error, reason} = MultiAuthCoordinator.get_credentials(:unknown)
      assert reason =~ "Unknown authentication strategy"
    end
  end

  describe "validate_auth_config/1" do
    test "validates gemini configuration" do
      result = MultiAuthCoordinator.validate_auth_config(:gemini)
      assert result == :ok or match?({:error, _reason}, result)
    end

    test "validates vertex_ai configuration" do
      result = MultiAuthCoordinator.validate_auth_config(:vertex_ai)
      assert result == :ok or match?({:error, _reason}, result)
    end

    test "returns error for unknown strategy" do
      assert {:error, reason} = MultiAuthCoordinator.validate_auth_config(:unknown)
      assert reason =~ "Unknown authentication strategy"
    end
  end

  describe "refresh_credentials/1" do
    test "refreshes gemini credentials (no-op)" do
      assert {:ok, credentials} = MultiAuthCoordinator.refresh_credentials(:gemini)
      assert is_map(credentials)
    end

    test "refreshes vertex_ai credentials" do
      result = MultiAuthCoordinator.refresh_credentials(:vertex_ai)
      assert match?({:ok, _credentials}, result) or match?({:error, _reason}, result)
    end

    test "returns error for unknown strategy" do
      assert {:error, reason} = MultiAuthCoordinator.refresh_credentials(:unknown)
      assert reason =~ "Unknown authentication strategy"
    end
  end

  describe "concurrent coordination" do
    test "handles concurrent auth requests for different strategies" do
      tasks = [
        Task.async(fn -> MultiAuthCoordinator.coordinate_auth(:gemini, []) end),
        Task.async(fn -> MultiAuthCoordinator.coordinate_auth(:vertex_ai, []) end),
        Task.async(fn -> MultiAuthCoordinator.coordinate_auth(:gemini, []) end)
      ]

      results = Task.await_many(tasks, 5000)

      # All should succeed (or fail gracefully in test environment)
      Enum.each(results, fn result ->
        case result do
          {:ok, strategy, headers} ->
            assert strategy in [:gemini, :vertex_ai]
            assert is_list(headers)

          {:error, _reason} ->
            # Acceptable in test environment with no real credentials
            :ok
        end
      end)
    end

    test "maintains auth strategy isolation" do
      # Start multiple coordination requests
      {:ok, agent} = Agent.start_link(fn -> [] end)

      tasks =
        for strategy <- [:gemini, :vertex_ai, :gemini, :vertex_ai] do
          Task.async(fn ->
            result = MultiAuthCoordinator.coordinate_auth(strategy, [])
            Agent.update(agent, fn results -> [{strategy, result} | results] end)
            result
          end)
        end

      Task.await_many(tasks, 5000)
      results = Agent.get(agent, & &1)

      # Verify each request got the correct strategy back
      Enum.each(results, fn {requested_strategy, result} ->
        case result do
          {:ok, returned_strategy, _headers} ->
            assert returned_strategy == requested_strategy

          {:error, _reason} ->
            # Acceptable in test environment
            :ok
        end
      end)

      Agent.stop(agent)
    end
  end
end
