defmodule TOfT.Anthropic.API do
  @moduledoc """
  A simple API wrapper for the Anthropic API using the Req library.
  """

  @base_url "https://api.anthropic.com"
  @api_version "v1"
  @model "claude-3-5-haiku-20241022"

  defp get_headers() do
    api_key = Application.fetch_env!(:t_of_t, TOfT.Anthropic) |> Keyword.fetch!(:api_key)

    [
      {"x-api-key", api_key},
      {"content-type", "application/json"},
      {"anthropic-version", "2023-06-01"}
    ]
  end

  defp build_url(endpoint) do
    "#{@base_url}/#{@api_version}/#{endpoint}"
  end

  def messages(system, messages, opts \\ []) do
    body = %{
      max_tokens: 1024,
      model: @model,
      messages: messages,
      system: system
    }

    body =
      if tools = Keyword.get(opts, :tools) do
        Map.put(body, :tools, tools)
      else
        body
      end

    headers = get_headers()

    %Req.Response{status: 200, body: body} =
      Req.post!(build_url("messages"), json: body, headers: headers)

    body
  end
end
