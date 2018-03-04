defmodule Thunk do
  @moduledoc """
  Laziness in Elixir. `Thunk`s are computations that have not yet happened.
  This module provides the `thunk` type and functions for manipulating and
  creating thunks.

  `Thunk`s allow for setting up a computation and transforming it without evaluating it.
  A `thunk` can be used by other thunks and evaluation is shared.

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
  @opaque thunk :: %__MODULE__{pid: pid}

  @typedoc """
  Alias for any.
  """
  @type element :: any

  @typep state ::
           {:const, (() -> any)}
           | {:error, Exception.t(), Exception.stacktrace()}
           | {:lambda, pid, reference, (any -> any)}

  @doc false
  @spec thunk(state) :: no_return
  # Constant
  def thunk({:const, f}) do
    receive do
      # To evaluate a constant evaluate and exit
      # with value.
      :eval ->
        x = f.()
        exit({:evaluated, x})
    end
  end

  # Error
  def thunk({:error, msg, stacktrace}) do
    receive do
      # To evaluate error reraise the error
      # that occured.
      :eval ->
        reraise(msg, stacktrace)
    end
  end

  # Lambda
  def thunk({:lambda, pid, ref, f}) do
    receive do
      # To evaluate a lambda send argument process :eval,
      # then apply function and exit.
      :eval ->
        send(pid, :eval)

        # Awaits result of argument thunk.
        receive do
          # Evaluates function with argument.
          {:DOWN, ^ref, :process, _, {:evaluated, x}} ->
            y = f.(x)
            exit({:evaluated, y})

          # If argument process raises an error,
          # propagate error.
          {:DOWN, ^ref, :process, _, {msg, stacktrace}} ->
            if Exception.exception?(msg) do
              reraise(msg, stacktrace)
            end

          # If argument process doesn't exist raise ThunkError.
          {:DOWN, ^ref, :process, _, :noproc} ->
            raise(ThunkError, {:noproc, pid})

          # If argument process killed raise ThunkError.
          {:DOWN, ^ref, :process, _, :killed} ->
            raise(ThunkError, {:killed, pid})
        end
    end
  end

  @doc """
  Suspends a value in a `thunk`. Doesn't evaluate it's argument.

  ## Example

      iex> Thunk.suspend(raise("Oops you evaluated me!"))
      #Thunk<...>
  """
  @spec suspend(any) :: thunk
  defmacro suspend(x) do
    quote do
      pid = spawn(Thunk, :thunk, [{:const, fn -> unquote(x) end}])
      %Thunk{pid: pid}
    end
  end

  @doc """
  Evaluates a `thunk`. Raises a `ThunkError` if already evaluated.

  ## Example 

      iex> thunk = Thunk.suspend(:value)
      iex> Thunk.force(thunk)
      :value
  """
  @spec force(thunk) :: any
  def force(thunk) do
    ref = Process.monitor(thunk.pid)
    send(thunk.pid, :eval)

    receive do
      # If evaluated return x.
      {:DOWN, ^ref, :process, _, {:evaluated, x}} ->
        x

      # If process doesn't exist raises
      # a ThunkError.
      {:DOWN, ^ref, :process, _, :noproc} ->
        raise(ThunkError, {:noproc, thunk.pid})

      # If receives an error, reraise it.
      {:DOWN, ^ref, :process, _, {msg, stacktrace}} ->
        if Exception.exception?(msg) do
          reraise(msg, stacktrace)
        end

      # If process was killed raise ThunkError.
      {:DOWN, ^ref, :process, _, :killed} ->
        raise(ThunkError, {:killed, thunk.pid})
    end
  end

  @doc """
  Is value a thunk?
  """
  @spec thunk?(any) :: boolean
  def thunk?(%__MODULE__{pid: _}), do: true
  def thunk?(_), do: false

  @doc """
  Applies a function to a `thunk`.

  ## Example

      iex> thunk_x = Thunk.suspend(1)
      iex> thunk_y = Thunk.map(thunk_x, fn x -> x + 1 end)
      iex> Thunk.force(thunk_y)
      2
  """
  @spec map(thunk, (element -> any)) :: thunk
  def map(thunk, f) do
    me = self()

    # Spawns a process that monitors argument
    # thunk, sends calling process :ok, and then 
    # behaves as thunk with lambda clause.
    pid =
      spawn(fn ->
        ref = Process.monitor(thunk.pid)
        send(me, :ok)
        thunk({:lambda, thunk.pid, ref, f})
      end)

    receive do
      :ok ->
        %__MODULE__{pid: pid}
    end
  end

  @doc """
  Is thunk still around?
  """
  @spec exists?(thunk) :: boolean
  def exists?(thunk), do: Process.alive?(thunk.pid)

  @doc """
  Deletes a thunk, to be used if the thunk 
  does not need to ever be evaluated.

  ## Example 

      iex> require Thunk
      iex> thunk = Thunk.suspend(:some_computation)
      iex> Thunk.delete(thunk)
      iex> Thunk.exists?(thunk)
      false
  """
  @spec delete(thunk) :: :ok
  def delete(thunk) do
    Process.exit(thunk.pid, :kill)
    :ok
  end

  @doc """
  Copies a thunk. When a thunk is evaluated it ceases to exist,
  so this function is useful for holding onto a result should it
  be evaluated.

  ## Example

      iex> thunk = Thunk.suspend(:some_computation)
      iex> thunk_copy = Thunk.copy(thunk)
      iex> Thunk.force(thunk)
      iex> Thunk.exists?(thunk)
      false
      iex> Thunk.force(thunk_copy)
      :some_computation
  """
  @spec copy(thunk) :: thunk
  def copy(thunk), do: map(thunk, fn x -> x end)
end

defmodule ThunkError do
  defexception [:message]

  def exception({:killed, pid}) do
    %__MODULE__{message: "Thunk, #{inspect(pid)}, was deleted"}
  end

  def exception({:noproc, pid}) do
    %__MODULE__{message: "Thunk, #{inspect(pid)}, already evaluated or was deleted."}
  end
end

defimpl Inspect, for: Thunk do
  import Inspect.Algebra

  def inspect(_, _) do
    string("#Thunk<...>")
  end
end
