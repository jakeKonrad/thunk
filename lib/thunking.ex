# Server module for thunks
#
defmodule Thunking do
  @moduledoc false

  # The delay state of a thunk process, has the suspended value
  # and a list of pids to send its forced value once forced.  
  def thunking(:delay, fun, ps) do
    receive do
      # Upon recieving the connect message will call its
      # self with the new process cons'd to its process
      # list.
      {:connect, p} ->
        thunking(:delay, fun, [p | ps])

      # Recieving force with a pid and ref, evaluates its
      # value, sends the value back to the pid that requested it
      # and then distributes the value around.
      {:force, pid, ref} ->
        y = fun.()
        send(pid, {:done, ref, y})
        distr(y, ps)

      # Similar to above method.
      :force ->
        y = fun.()
        distr(y, ps)
    end
  end

  # Similar to above clause. except has the pid of the 
  # thunk it expects a value from. 
  def thunking(:map, source, ref, fun, ps) do
    receive do
      {:connect, p} ->
        thunking(:map, source, ref, fun, [p | ps])

      {:force, pid, ref1} ->
        send(source, :force)

        receive do
          {:done, ^ref, x} ->
            y = fun.(x)
            send(pid, {:done, ref1, y})
            distr(y, ps)
        end

      :force ->
        send(source, :force)

        receive do
          {:done, ^ref, x} ->
            y = fun.(x)
            distr(y, ps)
        end

      {:done, ^ref, x} ->
        thunking(:delay, fn -> fun.(x) end, ps)
    end
  end

  # Combines two thunks.
  def thunking(:product, p1, r1, p2, r2, ps) do
    receive do
      {:connect, p} ->
        thunking(:product, p1, r1, p2, r2, [p | ps])

      {:force, pid, ref} ->
        send(p1, :force)
        send(p2, :force)

        receive do
          {:done, ^r1, x} ->
            receive do
              {:done, ^r2, y} ->
                z = {x, y}
                send(pid, {:done, ref, z})
                distr(z, ps)
            end

          {:done, ^r2, y} ->
            receive do
              {:done, ^r1, x} ->
                z = {x, y}
                send(pid, {:done, ref, z})
                distr(z, ps)
            end
        end

      :force ->
        send(p1, :force)
        send(p2, :force)

        receive do
          {:done, ^r1, x} ->
            receive do
              {:done, ^r2, y} ->
                z = {x, y}
                distr(z, ps)
            end

          {:done, ^r2, y} ->
            receive do
              {:done, ^r1, x} ->
                z = {x, y}
                distr(z, ps)
            end
        end

      {:done, ^r1, x} ->
        thunking(:product1, x, p2, r2, ps)

      {:done, ^r2, y} ->
        thunking(:product2, p1, r1, y, ps)
    end
  end

  def thunking(:product1, x, p2, r2, ps) do
    receive do
      {:connect, p} ->
        thunking(:product1, x, p2, r2, [p | ps])

      {:force, pid, ref} ->
        send(p2, :force)

        receive do
          {:done, ^r2, y} ->
            z = {x, y}
            send(pid, {:done, ref, z})
            distr(z, ps)
        end

      :force ->
        send(p2, :force)

        receive do
          {:done, ^r2, y} ->
            z = {x, y}
            distr(z, ps)
        end

      {:done, ^r2, y} ->
        thunking(:done, {x, y}, ps)
    end
  end

  def thunking(:product2, p1, r1, y, ps) do
    receive do
      {:connect, p} ->
        thunking(:product2, p1, r1, y, [p | ps])

      {:force, pid, ref} ->
        send(p1, :force)

        receive do
          {:done, ^r1, x} ->
            z = {x, y}
            send(pid, {:done, ref, z})
            distr(z, ps)
        end

      :force ->
        send(p1, :force)

        receive do
          {:done, ^r1, x} ->
            z = {x, y}
            distr(z, ps)
        end

      {:done, ^r1, x} ->
        thunking(:done, {x, y}, ps)
    end
  end

  def thunking(:done, x, ps) do
    receive do
      {:connect, p} ->
        thunking(:done, x, [p | ps])

      {:force, pid, ref} ->
        send(pid, {:done, ref, x})
        distr(x, ps)

      :force ->
        distr(x, ps)
    end
  end

  # Helper function to distribute values amongst processes.
  defp distr(_, []), do: exit(:normal)

  defp distr(x, [{pid, ref} | ps]) do
    send(pid, {:done, ref, x})
    distr(x, ps)
  end
end
