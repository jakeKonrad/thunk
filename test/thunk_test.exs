defmodule ThunkTest do
  use ExUnit.Case
  doctest Thunk

  test "greets the world" do
    assert Thunk.hello() == :world
  end
end
