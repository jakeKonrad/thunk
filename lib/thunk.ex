defmodule Thunk do
  @moduledoc """
  Laziness in Elixir. Thunks are computations that have not yet happened.
  This module provides the thunk type and functions for manipulating and
  creating thunks.

  Thunks allow for setting up a computation and transforming it without evaluating it.
  A thunk can be used by other thunks and evaluation is shared.

  ## Example

      defmodule Infinity do
        require Thunk  

        @doc \"\"\"
        An infinite list that just repeats its argument.
        
        ## Example
        
            iex> xs = Infinity.repeatedly(1)
            #Thunk<...>
            iex> [h | t] = Thunk.force(xs)
            [1 | #Thunk<...>]
        \"\"\"
        def repeatedly(x) do
          Thunk.suspend([x | repeatedly(x)])
        end
      end
  """

  # Wrapper around thunk pid.
  @enforce_keys [:pid]
  defstruct [:pid]

  @typedoc """
  Thunk type.
  """
  @opaque t :: %__MODULE__{pid: pid}

  @typedoc """
  Alias for any.
  """
  @type element :: any

  # @typep msg ::
  #         {:forced, reference, any}
  #         | {:bind, reference, pid}
  #         | :force

  @typep expr ::
           {:var, (() -> any)}
           | {:lambda, reference, pid, (any -> any)}
           | {:apply, reference, pid, reference, pid}

  @doc false
  @spec thunk(expr, [{:bind, reference, pid}]) :: no_return
  def thunk(expr = {:var, f}, binds) do
    receive do
      bind = {:bind, _, _} ->
        thunk(expr, [bind | binds])

      :force ->
        x = f.()
        do_thunk(x, binds)
    end
  end

  def thunk(expr = {:lambda, ref, pid, f}, binds) do
    receive do
      bind = {:bind, _, _} ->
        thunk(expr, [bind | binds])

      :force ->
        send(pid, :force)

        receive do
          {:forced, ^ref, x} ->
            y = f.(x)
            do_thunk(y, binds)
        end
    end
  end

  def thunk(expr = {:apply, ref_f, pid_f, ref_x, pid_x}, binds) do
    receive do
      bind = {:bind, _, _} ->
        thunk(expr, [bind | binds])

      :force ->
        send(pid_f, :force)
        send(pid_x, :force)

        receive do
          {:forced, ^ref_f, f} ->
            receive do
              {:forced, ^ref_x, x} ->
                y = f.(x)
                do_thunk(y, binds)
            end

          {:forced, ^ref_x, x} ->
            receive do
              {:forced, ^ref_f, f} ->
                y = f.(x)
                do_thunk(y, binds)
            end
        end
    end
  end

  defp do_thunk(_, []), do: exit(:normal)

  defp do_thunk(x, [{:bind, ref, pid} | binds]) do
    send(pid, {:forced, ref, x})
    do_thunk(x, binds)
  end

  @doc """
  Suspends a value in a thunk. Doesn't evaluate it's argument. Can be used
  as a do block as well.

  ## Example

      iex> Thunk.suspend(raise("Oops you evaluated me!"))
      #Thunk<...>
      iex> Thunk.suspend do
      ...>   x = 5
      ...>   y = 6
      ...>   x + y
      ...> end
      #Thunk<...>
  """
  @spec suspend(any) :: t
  defmacro suspend(x) do
    do_suspend(x)
  end

  defp do_suspend(do: block) do
    quote do
      fun = fn -> unquote(block) end
      pid = spawn(Thunk, :thunk, [{:var, fun}, []])
      %Thunk{pid: pid}
    end
  end

  defp do_suspend(value) do
    quote do
      fun = fn -> unquote(value) end
      pid = spawn(Thunk, :thunk, [{:var, fun}, []])
      %Thunk{pid: pid}
    end
  end

  @doc """
  Forces a thunk. Raises a ThunkError if already forced or deleted.

  ## Example 

      iex> thunk = Thunk.suspend(:value)
      iex> Thunk.force(thunk)
      :value
  """
  @spec force(t) :: any
  def force(thunk) do
    ref = bind_to(thunk.pid)
    send(thunk.pid, :force)

    receive do
      {:forced, ^ref, x} -> x
    end
  end

  @doc """
  Is value a thunk?
  """
  @spec thunk?(any) :: boolean
  def thunk?(%__MODULE__{pid: _}), do: true
  def thunk?(_), do: false

  @doc """
  Applies a function to a thunk.

  ## Example

      iex> thunk_x = Thunk.suspend(1)
      iex> thunk_y = Thunk.map(thunk_x, fn x -> x + 1 end)
      iex> Thunk.force(thunk_y)
      2
  """
  @spec map(t, (element -> any)) :: t
  def map(thunk, f) do
    me = self()

    pid =
      spawn(fn ->
        ref = bind_to(thunk.pid)
        send(me, :ok)
        thunk({:lambda, ref, thunk.pid, f}, [])
      end)

    receive do
      :ok -> %__MODULE__{pid: pid}
    end
  end

  @doc """
  Given a thunk with a function and a thunk
  with it's argument, returns a thunk with the result
  of their application. 

  ## Example

      iex> defmodule ThunkyMath do
      ...>   require Thunk   
      ...>
      ...>   # Add two thunks
      ...>   def add(x, y) do
      ...>    addr = fn n1 -> fn n2 -> n1 + n2 end end
      ...>     Thunk.map(x, addr)
      ...>     |> Thunk.apply(y)
      ...>   end
      ...> end
      iex> x = Thunk.suspend(12)
      iex> y = Thunk.suspend(13)
      iex> z = ThunkyMath.add(x, y)
      #Thunk<...>
      iex> Thunk.force(z)
      25
  """
  @spec apply(t, t) :: t
  def apply(thunk_f, thunk_x) do
    me = self()

    pid =
      spawn(fn ->
        ref_f = bind_to(thunk_f.pid)
        ref_x = bind_to(thunk_x.pid)
        send(me, :ok)
        thunk({:apply, ref_f, thunk_f.pid, ref_x, thunk_x.pid}, [])
      end)

    receive do
      :ok -> %__MODULE__{pid: pid}
    end
  end

  defp bind_to(pid) do
    try do
      Process.link(pid)
      ref = make_ref()
      send(pid, {:bind, ref, self()})
      ref
    rescue
      ErlangError ->
        raise(
          ThunkError,
          message: "thunk has already been forced or deleted"
        )
    end
  end

  @doc """
  Is thunk still around?
  """
  @spec exists?(t) :: boolean
  def exists?(thunk), do: Process.alive?(thunk.pid)

  @doc """
  Deletes a thunk, to be used if the thunk 
  does not need to ever be evaluated.

  ## Example 

      iex> thunk = Thunk.suspend(:some_computation)
      iex> Thunk.delete(thunk)
      iex> Thunk.exists?(thunk)
      false
  """
  @spec delete(t) :: true
  def delete(thunk) do
    Process.exit(thunk.pid, :kill)
    true
  end

  @doc """
  Copies a thunk. When a thunk is forced it ceases to exist,
  so this function is useful for holding onto a result should it
  be forced.

  ## Example

      iex> thunk = Thunk.suspend(:some_computation)
      iex> thunk_copy = Thunk.copy(thunk)
      iex> Thunk.force(thunk)
      iex> Thunk.exists?(thunk)
      false
      iex> Thunk.force(thunk_copy)
      :some_computation
  """
  @spec copy(t) :: t
  def copy(thunk), do: map(thunk, fn x -> x end)
end

defmodule ThunkError do
  defexception [:message]
end

defimpl Inspect, for: Thunk do
  import Inspect.Algebra

  def inspect(_, _) do
    string("#Thunk<...>")
  end
end
