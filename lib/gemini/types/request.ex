defmodule Gemini.Types.Request do
  @moduledoc """
  Request types for the Gemini API.
  """

  alias Gemini.Types.{Content, SafetySetting, GenerationConfig}
end

defmodule Gemini.Types.Request.GenerateContentRequest do
  @moduledoc """
  Request for generating content.
  """

  use TypedStruct

  alias Gemini.Types.{Content, SafetySetting, GenerationConfig}

  @derive Jason.Encoder
  typedstruct do
    field :contents, [Content.t()], enforce: true
    field :tools, [map()], default: []
    field :tool_config, map() | nil, default: nil
    field :safety_settings, [SafetySetting.t()], default: []
    field :system_instruction, Content.t() | nil, default: nil
    field :generation_config, GenerationConfig.t() | nil, default: nil
  end
end

defmodule Gemini.Types.Request.ListModelsRequest do
  @moduledoc """
  Request for listing models.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :page_size, integer() | nil, default: nil
    field :page_token, String.t() | nil, default: nil
  end
end

defmodule Gemini.Types.Request.GetModelRequest do
  @moduledoc """
  Request for getting a specific model.
  """

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :name, String.t(), enforce: true
  end
end

defmodule Gemini.Types.Request.CountTokensRequest do
  @moduledoc """
  Request for counting tokens.
  """

  use TypedStruct

  alias Gemini.Types.Content

  @derive Jason.Encoder
  typedstruct do
    field :contents, [Content.t()], enforce: true
  end
end
