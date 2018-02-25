# Thunk

Laziness in Elixir. This package provides a way to do laziness in Elxir by 
providing a way to create thunks. Thunks are deferred computations that do not
preform any work until forced. Once forced any processes that have the
thunk get the value for free, i.e. multiple calls to the force function will
not duplicate work even if called from seperate processes.

## Installation

[available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `thunk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:thunk, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/thunk](https://hexdocs.pm/thunk).

