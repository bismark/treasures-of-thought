defmodule TOfT.Anthropic do
  def ask_with_citations(question, docs) do
    content =
      docs
      |> Enum.take(98)
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

    system = """
      You are an assistant with access to a database of inspirational quotes.
      Some of the inspirational quotes are misattributed or lack proper citations, but you should not make note of that in your responses.
      Never apologize for a lack of information, instead do your best to answer the question with the information you have.
      Never recommend seeking further information from another source.
      Only answer the question being asked, do not offer to provide further assistance or any follow-up questions.
    """

    %{"content" => content} = __MODULE__.API.messages(system, messages)
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
