defmodule Gemini.Types.Part do
  @moduledoc """
  Part type for content in Gemini API.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    @typedoc "Text content."
    field :text, String.t() | nil, default: nil

    @typedoc "Inline data (base64 encoded)."
    field :inline_data, Gemini.Types.Blob.t() | nil, default: nil
  end

  @doc """
  Create a text part.
  """
  def text(text) when is_binary(text) do
    %__MODULE__{text: text}
  end

  @doc """
  Create an inline data part with base64 encoded data.
  """
  def inline_data(data, mime_type) when is_binary(data) and is_binary(mime_type) do
    blob = Gemini.Types.Blob.new(data, mime_type)
    %__MODULE__{inline_data: blob}
  end

  @doc """
  Create a blob part with raw data and MIME type.
  """
  def blob(data, mime_type) when is_binary(data) and is_binary(mime_type) do
    blob = Gemini.Types.Blob.new(data, mime_type)
    %__MODULE__{inline_data: blob}
  end

  @doc """
  Create a part from a file path.
  """
  def file(path) when is_binary(path) do
    case Gemini.Types.Blob.from_file(path) do
      {:ok, blob} -> %__MODULE__{inline_data: blob}
      {:error, _error} -> %__MODULE__{text: "Error loading file: #{path}"}
    end
  end
end
