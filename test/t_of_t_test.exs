defmodule TOfTTest do
  use ExUnit.Case
  doctest TOfT

  test "greets the world" do
    assert TOfT.hello() == :world
  end
end
