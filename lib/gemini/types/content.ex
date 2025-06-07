defmodule Gemini.Types.Content do
  @moduledoc """
  Content type for Gemini API requests and responses.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    @typedoc "The role of the content creator."
    field :role, String.t(), default: "user"

    @typedoc "Ordered parts that constitute a single message."
    field :parts, [Gemini.Types.Part.t()], default: []
  end

  @doc """
  Create content with text.
  """
  def text(text, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [Gemini.Types.Part.text(text)]
    }
  end

  @doc """
  Create content with text and image.
  """
  def multimodal(text, image_data, mime_type, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [
        Gemini.Types.Part.text(text),
        Gemini.Types.Part.inline_data(image_data, mime_type)
      ]
    }
  end

  @doc """
  Create content with an image from a file path.
  """
  def image(path, role \\ "user") do
    %__MODULE__{
      role: role,
      parts: [Gemini.Types.Part.file(path)]
    }
  end
end
