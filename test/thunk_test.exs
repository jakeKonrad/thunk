defmodule ThunkTest do
  use ExUnit.Case
  import Kernel, except: [apply: 2, apply: 3]
  import Thunk

  doctest Thunk, except: [:moduledoc]

  test "First Functor Law" do
    id = fn x -> x end
    v = suspend(:test)
    lhs = map(v, id)
    rhs = id.(v)
    rhs = force(rhs) # Have to force rhs first otherwise the lhs 
                     # will force the rhs before it is used.
    assert force(lhs) == rhs
  end

  test "Second Functor Law" do
    f = &Atom.to_string/1
    g = &String.to_atom/1
    v = suspend(:test)
    lhs = map(v, fn x -> g.(f.(x)) end)
    rhs = map(map(v, f), g)
    assert force(lhs) == force(rhs)
  end

  test "First Applicative Law / Identity" do
    v = suspend(:test)
    lhs =
      suspend(fn x -> x end)
      |> apply(v)
    rhs = force(v)
    assert force(lhs) == rhs
  end

  test "Second Applicative Law / Homomorphism" do
    x = :test
    f = &Atom.to_string/1
    lhs =
      suspend(f)
      |> apply(suspend(x))
    rhs =
      suspend(f.(x))
    assert force(lhs) == force(rhs)
  end

  test "Third Applicative Law / Interchange" do
    y = :test 
    u = suspend(&Atom.to_string/1)
    lhs =
      apply(u, suspend(y))
    rhs =
      suspend(fn f -> f.(y) end)
      |> apply(u)
    assert force(lhs) == force(rhs)
  end

  test "Forth Applicative Law / Composition" do
    u = suspend(&String.to_atom/1)
    v = suspend(&Atom.to_string/1)
    w = suspend(:test)
    lhs = 
      suspend(fn g -> fn f -> fn x -> g.(f.(x)) end end end)
      |> apply(u)
      |> apply(v)
      |> apply(w)
    rhs = 
      apply(u, apply(v, w))
    assert force(lhs) == force(rhs)
  end
end
