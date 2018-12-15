# Client module for thunks
#
#         delay      force
# () => A -----> T A -----> A
#                 |         |
#                 | map(f)  | f
#                 |         |
#         delay  \|/ force \|/
# () => B -----> T B -----> B 
#
# f . force . delay ~= force . map(f) . delay
#
defmodule Thunk do
  @moduledoc """
  This module provides Thunks. A thunk holds a value thats not yet
  been computed. This values can have functions applied to them without forcing the value
  and two thunks can be combined into a tuple again without forcing either of them.
  The documentation for the functions has Haskell like type signatures these are only
  there to improve understanding and give a better idea of how these functions should
  behave.
  """

  @enforce_keys [:pid]
  defstruct [:pid]

  @typedoc "The Thunk type."
  @opaque t :: %Thunk{pid: pid()}

  @doc """
  Delays the evaluation of a value.

  delay : (() -> a) -> Thunk a
  """
  @spec delay((() -> any())) :: t
  def delay(fun) when is_function(fun, 0) do
    # spawns a process in state delay
    pid = spawn(fn -> Thunking.thunking(:delay, fun, []) end)
    %Thunk{pid: pid}
  end

  @doc """
  Forces evaluation of a thunk.

  force : Thunk a -> a
  """
  @spec force(t) :: any
  def force(%Thunk{pid: pid}) do
    me = self()
    ref = make_ref()
    # sends the thunk process a message 
    # telling it to force and gives it 
    # this ref and this pid
    # N.B. this doesn't check if thunk process 
    # exists and will just hang if attempted 
    # on a thunk process that does not 
    # exists
    send(pid, {:force, ref, me})

    receive do
      # matches on this ref and then 
      # returns the value
      {:done, ^ref, val} ->
        val
    end
  end

  @doc """
  Lifts a function to work on thunks.

  map : Thunk a -> (a -> b) -> Thunk b
  """
  @spec map(t, (any() -> any())) :: t
  def map(%Thunk{pid: pid}, fun) do
    me = self()

    pid1 =
      spawn(fn ->
        me1 = self()
        ref = make_ref()
        # sends the process it gets its 
        # argument from a message asking to
        # connect it.
        send(pid, {:connect, {me1, ref}})
        # sends the calling process :ok
        # to ensure that it won't force this
        # process to early, i.e. before its argument
        # process receives its connect message.
        send(me, :ok)
        Thunking.thunking(:map, pid, ref, fun, [])
      end)

    receive do
      :ok ->
        %Thunk{pid: pid1}
    end
  end

  @doc """
  Given two thunks returns a thunk containing
  a tuple made of the two values in the argument
  thunks.

  product : Thunk a -> Thunk b -> Thunk (a, b)
  """
  @spec product(t, t) :: t
  def product(%Thunk{pid: p1}, %Thunk{pid: p2}) do
    me = self()

    p3 =
      spawn(fn ->
        me1 = self()
        r1 = make_ref()
        r2 = make_ref()
        # this has two argument processes but 
        # other than that is not much different
        # that the map function.
        send(p1, {:connect, {me1, r1}})
        send(p2, {:connect, {me1, r2}})
        send(me, :ok)
        Thunking.thunking(:product, p1, r1, p2, r2, [])
      end)

    receive do
      :ok ->
        %Thunk{pid: p3}
    end
  end

  @doc """
  A macro that turns a value into a thunk.

  (~~~) : a -> Thunk a
  """
  @spec ~~~any() :: t
  defmacro ~~~val do
    quote do
      Thunk.delay(fn -> unquote(val) end)
    end
  end
end

defimpl Inspect, for: Thunk do
  import Inspect.Algebra

  def inspect(_, _) do
    string("#Thunk<...>")
  end
end
