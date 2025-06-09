import Config

# Runtime configuration (production)
if config_env() == :prod do
  # Configure from environment variables in production
  if api_key = System.get_env("GEMINI_API_KEY") do
    config :gemini, api_key: api_key
  end

  if project_id = System.get_env("VERTEX_PROJECT_ID") do
    config :gemini, vertex_project_id: project_id
  end

  if location = System.get_env("VERTEX_LOCATION") do
    config :gemini, vertex_location: location
  end
end
