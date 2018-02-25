defmodule ThunkTest do
  use ExUnit.Case

  require Thunk

  test "Suspend does not evaluate argument" do
    Thunk.suspend(raise("Oops, suspend evaluated its argument"))
  end

  test "Force extracts value of thunk" do
    thunk = Thunk.suspend(1)
    assert Thunk.force(thunk) == 1
  end

  test "Map applies function to thunk" do
    thunk1 = Thunk.suspend(1)
    thunk2 = Thunk.map(thunk1, fn x -> x + 1 end)
    assert Thunk.force(thunk2) == 2
  end

  test "Map does not force thunk" do
    thunk = Thunk.suspend(raise("Oops, map evaluated the thunk"))
    Thunk.map(thunk, fn _err -> nil end)
  end

  test "Map does not alter value of old thunk" do
    thunk1 = Thunk.suspend(1)
    _thunk2 = Thunk.map(thunk1, fn x -> x + 1 end)
    assert Thunk.force(thunk1) == 1
  end
end
