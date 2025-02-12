defmodule TOfT.Anthropic do
  require Logger

  @system_prompt """
      You are an assistant with access to a database of inspirational quotes.
      Some of the inspirational quotes are misattributed or lack proper citations, but you should not make note of that in your responses.
      Never apologize for a lack of information, instead do your best to answer the question with the information you have.
      Never recommend seeking further information from another source.
      Only answer the question being asked, do not offer to provide further assistance or any follow-up questions.
    """

  @tools [
      %{
        name: :get_todays_quote,
        description: "Get the given quote for today",
        input_schema: %{
          type: :object,
          properties: %{}
        }
      },
      %{
        name: :get_quotes_by_date,
        description: "Get a list of quotes for a given day of the year.",
        input_schema: %{
          type: :object,
          properties: %{
            month: %{
              type: :integer,
              description: "The month of the year (1-12).",
            },
            day: %{
              type: :integer,
              description: "The day of the month (1-31).",
            }
          },
          required: [:month, :day]
        }
      },
      # %{
      #   name: :get_authors,
      #   description: "Get the list of authors in the database.",
      #   input_schema: %{
      #     type: :object,
      #     properties: %{}
      #   }
      # },
      # %{
      #   name: :get_quotes_by_author,
      #   description: "Get a list of quotes by a specific author.",
      #   input_schema: %{
      #     type: :object,
      #     properties: %{
      #       name: %{
      #         type: :string,
      #         description: "The name of the author."
      #       }
      #     },
      #   }
      # }
    ]

  valid_tools = Enum.map(@tools, &Map.fetch!(&1, :name))
  @valid_tools MapSet.new(valid_tools ++ Enum.map(valid_tools, &Atom.to_string/1))

  def ask_with_tools(question) do
    messages = [
      %{
        role: :user,
        content: [
          %{
            type: :text,
            text: question
          }
        ]
      }
    ]

    %{"content" => content} = __MODULE__.API.messages(@system_prompt, messages, tools: @tools, tool_choice: :any)
    maybe_use_tools(messages, content)
  end

  defp maybe_use_tools(messages, content) do
    if Enum.any?(content, fn %{"type" => type} -> type == "tool_use" end) do
      Logger.info("Using tools")
      tool_requests = Enum.filter(content, fn 
        %{"type" => "tool_use", "name" => tool_name} -> MapSet.member?(@valid_tools, tool_name)
        _ -> false
      end)

      new_content =
        Enum.map(tool_requests, fn %{"name" => tool_name, "input" => input, "id" => id} ->
          Logger.info("Using tool #{tool_name}")
          case tool_name do
            "get_todays_quote" ->
              get_todays_quote(id)

            "get_quotes_by_date" ->
              %{"month" => month, "day" => day} = input
              get_quotes_by_date(month, day, id)

            "get_authors" ->
              get_authors(id)

            # "get_quotes_by_author" ->
            #   %{"name" => name} = input
            #   get_quotes_by_author(name)
          end
        end)

      messages = messages ++ [%{role: :assistant, content: content}, %{role: :user, content: new_content}]
      %{"content" => content} = __MODULE__.API.messages(@system_prompt, messages, tools: @tools)
      maybe_use_tools(messages, content)
    else
      List.last(content)
      |> print_response()
    end
  end

  def get_authors(id) do
    authors =
      TOfT.data()
      |> Enum.flat_map(fn {_date, quotes} ->
        quotes
        |> Enum.reject(fn %{attribution: nil} -> true; _ -> false end)
        |> Enum.map(fn %{"attribution" => attribution} -> attribution end)
      end)
      |> Enum.uniq()
      |> Enum.sort()

    # make tool_result AI!

  end

  defp get_todays_quote(id) do
    today = Date.utc_today()
    get_quotes_by_date(today.month, today.day, id)
  end

  defp get_quotes_by_date(month, day, id) do
    month_str = month |> Integer.to_string() |> String.pad_leading(2, "0")
    day_str = day |> Integer.to_string() |> String.pad_leading(2, "0")

    date = "#{month_str}-#{day_str}"
    data = TOfT.data()
    %{"text" => text, "attribution" => attribution} = Map.fetch!(data, date) |> hd()
    attribution = with nil <- attribution, do: "Unknown"

    %{
      type: :tool_result,
      tool_use_id: id,
      content: [
        %{
          type: :document,
          source: %{
            type: :text,
            media_type: "text/plain",
            data: text
          },
          title: date,
          context: "Attribution: #{attribution}",
          citations: %{enabled: true}
        }
      ]
    }
  end

  def ask_with_citations(question, docs) do
    content =
      docs
      |> Enum.take(99)
      |> Enum.map(fn {title, doc} ->
        %{"text" => text, "attribution" => attribution} = hd(doc)
        attribution = with nil <- attribution, do: "Unknown"

        %{
          type: :document,
          source: %{
            type: :text,
            media_type: "text/plain",
            data: text
          },
          title: title,
          context: "Attribution: #{attribution}",
          citations: %{enabled: true}
        }
      end)

    content =
      content ++
        [
          %{
            type: :text,
            text: question
          }
        ]

    messages = [
      %{
        role: :user,
        content: content
      }
    ]

    %{"content" => content} = __MODULE__.API.messages(@system_prompt, messages)
    #IO.inspect(content)
    print_response(content)
  end

  def print_response(content) do
    Enum.each(content, fn message ->
      case message do
        %{"citations" => citations} ->
          %{"document_title" => title} = hd(citations)
          %{"text" => text} = message
          IO.write("\e[1m" <> humanize_date(title) <> ":\e[22m\n")
          IO.write("\e[1m" <> text <> "\e[22m\n")

        %{"text" => text} ->
          IO.write(text)
      end
    end)
  end

  defp humanize_date(date) do
    [month, day] = String.split(date, "-", limit: 2)

    month =
      Map.fetch!(
        %{
          "01" => "January",
          "02" => "February",
          "03" => "March",
          "04" => "April",
          "05" => "May",
          "06" => "June",
          "07" => "July",
          "08" => "August",
          "09" => "September",
          "10" => "October",
          "11" => "November",
          "12" => "December"
        },
        month
      )

    day = to_ordinal(String.to_integer(day))
    "#{month} #{day}"
  end

  def to_ordinal(n) when is_integer(n) and n > 0 do
    suffix =
      case rem(n, 100) do
        11 ->
          "th"

        12 ->
          "th"

        13 ->
          "th"

        _ ->
          case rem(n, 10) do
            1 -> "st"
            2 -> "nd"
            3 -> "rd"
            _ -> "th"
          end
      end

    "#{n}#{suffix}"
  end

  def to_ordinal(_), do: raise(ArgumentError, "Input must be a positive integer")
end
