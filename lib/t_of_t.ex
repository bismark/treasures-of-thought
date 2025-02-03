defmodule TOfT do
  def data do
    "restructured_treasures_of_thought.json"
    |> File.read!()
    |> JSON.decode!()
  end

  def ask_question(question) do
    data = data()
    __MODULE__.Anthropic.ask_with_citations(question, data)
  end
end
