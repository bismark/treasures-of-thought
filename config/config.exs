import Config

config :t_of_t, TOfT.Anthropic, api_key: System.get_env("ANTHROPIC_API_KEY")
