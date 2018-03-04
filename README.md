# Thunk

This package provides a way to do laziness in Elxir. Contains functions to build
thunks from elixir terms and combinators for more complex computations. Evaluation
uses a call-by-need-ish strategy.

## Installation

[Available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `thunk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:thunk, "~> 0.2.0"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/thunk](https://hexdocs.pm/thunk).

