defmodule Thunk do
  @moduledoc """
  Laziness in Elixir. Thunks are computations that have not yet happened.
  This module provides the thunk type and functions for manipulating and
  creating thunks.
  """

  # Contains the pid of the thunk process.
  @doc false
  @enforce_keys [:pid]
  defstruct [:pid]

  @typedoc "A thunk. Thunks represent a computation yet to happen."
  @opaque t :: %__MODULE__{pid: pid}

  # The thunk process, responsible for maintaining 
  # state of the thunk. Provides two "methods", get and force.
  # Get just sends the internal state to the calling process and force
  # evaluates the thunk and sends the resulting value to the calling process.
  @doc false
  def thunk(value) do
    receive do
      {:get, pid} ->
        send(pid, value)
        thunk(value)

      {:force, pid} ->
        case value do
          {:unboxed, x} ->
            send(pid, x)
            thunk(value)

          {:boxed, fx} ->
            x = fx.()
            send(pid, x)
            thunk({:unboxed, x})
        end
    end
  end

  # Helper functions to create thunks.
  @doc false
  def to_thunk(x) do
    %__MODULE__{pid: spawn_link(fn -> thunk(x) end)}
  end

  @doc "Suspends a value in a thunk."
  @spec suspend(term) :: t
  defmacro suspend(x) do
    quote do
      fx = fn -> unquote(x) end
      Thunk.to_thunk({:boxed, fx})
    end
  end

  @doc """
  Given a thunk and a function returns a new thunk where the value in
  the thunk has had the function applied to it without forcing the evaluation.
  """
  @spec map(t, (term -> any)) :: t
  def map(thunk, f) do
    me = self()
    send(thunk.pid, {:get, me})

    receive do
      {:unboxed, x} ->
        to_thunk({:unboxed, f.(x)})

      {:boxed, fx} ->
        fy = fn -> f.(fx.()) end
        to_thunk({:boxed, fy})
    end
  end

  @doc "Forces the evaluation of the thunk and returns the value contained"
  @spec force(t) :: term
  def force(thunk) do
    me = self()
    send(thunk.pid, {:force, me})

    receive do
      x -> x
    end
  end
end

defimpl Inspect, for: Thunk do
  import Inspect.Algebra

  def inspect(_, _) do
    string("...")
  end
end
