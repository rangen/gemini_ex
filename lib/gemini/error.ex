defmodule Gemini.Error do
  @moduledoc """
  Standardized error structure for Gemini client.
  """

  use TypedStruct

  typedstruct do
    @typedoc "The type of error."
    field :type, atom(), enforce: true

    @typedoc "A human-readable message describing the error."
    field :message, String.t(), enforce: true

    @typedoc "The HTTP status code, if the error originated from an HTTP response."
    field :http_status, integer() | nil, default: nil

    @typedoc "API-specific error code or reason, if provided by Gemini."
    field :api_reason, term() | nil, default: nil

    @typedoc "Additional details or context about the error."
    field :details, map() | nil, default: nil

    @typedoc "The original error term, if this error is wrapping another."
    field :original_error, term() | nil, default: nil
  end

  @doc """
  Create a new error with type and message.
  """
  def new(type, message, attrs \\ []) do
    struct!(__MODULE__, [{:type, type}, {:message, message} | attrs])
  end

  @doc """
  Create an HTTP error.
  """
  def http_error(status, message, details \\ %{}) do
    new(:http_error, message, http_status: status, details: details)
  end

  @doc """
  Create an API error from Gemini response.
  """
  def api_error(reason, message, details \\ %{}) do
    new(:api_error, message, api_reason: reason, details: details)
  end

  @doc """
  Create a configuration error.
  """
  def config_error(message, details \\ %{}) do
    new(:config_error, message, details: details)
  end

  @doc """
  Create a request validation error.
  """
  def validation_error(message, details \\ %{}) do
    new(:validation_error, message, details: details)
  end

  @doc """
  Create a JSON serialization/deserialization error.
  """
  def serialization_error(message, details \\ %{}) do
    new(:serialization_error, message, details: details)
  end

  @doc """
  Create a network/connection error.
  """
  def network_error(message, original_error \\ nil) do
    new(:network_error, message, original_error: original_error)
  end

  @doc """
  Create an invalid response error.
  """
  def invalid_response(message, details \\ %{}) do
    new(:invalid_response, message, details: details)
  end
end
