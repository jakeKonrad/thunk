defmodule ThunkTest do
  use ExUnit.Case, async: true
  require Thunk
  doctest Thunk, except: [:moduledoc]

  test "Error propagation" do
    thunk = Thunk.suspend(raise("Fail"))
    thunk_copy = Thunk.copy(thunk)
    assert_raise RuntimeError, fn -> Thunk.force(thunk_copy) end
  end

  test "Thunk deletion error" do
    thunk = Thunk.suspend(:computation)
    Thunk.delete(thunk)
    assert_raise ThunkError, fn -> Thunk.force(thunk) end
  end
end
