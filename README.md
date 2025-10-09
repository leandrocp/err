# Err

[![Hex.pm](https://img.shields.io/hexpm/v/err.svg)](https://hex.pm/packages/err)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/err)

<!-- MDOC -->

**Err** is a tiny library that makes working with tagged `{:ok, value}` and `{:error, reason}` tagged tuples more ergonomic and expressive in Elixir.

It follows a simple design to permit using it in existing codebases without changing existing code:

- Tuples `{:ok, _}` (of any size) are considered a success result.
- Tuples `{:error, _}` (of any size) are considered an error result.
- `nil` is considered "none" or empty.
- Any other value is considered "some" value

Inspired by Rust's [Result](https://doc.rust-lang.org/std/result/enum.Result.html)/[Option](https://doc.rust-lang.org/std/option/enum.Option.html) and Gleam's [result](https://hexdocs.pm/gleam_stdlib/gleam/result.html)/[option](https://hexdocs.pm/gleam_stdlib/gleam/option.html).

## Features

- ⛓ **Composable** - Chain operations with `map`, `and_then`, `or_else`
- 🔌 **Drop-in compatibility** - Handles existing tagged tuples `:ok`/`:error` of any size and `nil` values. No need to introduce `%Result{}` structs or special atoms.
- ✨ **Just functions** - No complex custom pipe operators or DSL
- 🪶 **Zero dependencies** - Lightweight and fast
- 📦 **List operations** - Combine results with `all`, extract with `values`, split with `partition`
- ⚡ **Lazy evaluation** - Avoid computation with `_lazy` variants
- 🔄 **Transformations** - Replace, flatten, and transform results

## Installation

Add `err` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:err, "~> 0.2"}
  ]
end
```

## Usage

*Wrap values*

```elixir
iex> Err.ok(42)
{:ok, 42}

iex> Err.error(:timeout)
{:error, :timeout}
```

*Unwrap with defaults*

```elixir
iex> Err.unwrap_or({:ok, "config.json"}, "default.json")
"config.json"

iex> Err.unwrap_or({:error, :not_found}, "default.json")
"default.json"
```

*Lazy unwrapping (function only called when needed)*

```elixir
iex> Err.unwrap_or_lazy({:error, :enoent}, fn reason -> "Error: #{reason}" end)
"Error: enoent"
```

*Transform success values*

```elixir
iex> Err.map({:ok, 5}, fn num -> num * 2 end)
{:ok, 10}
```

*Transform error values*

```elixir
iex> Err.map_err({:error, :timeout}, fn reason -> "#{reason}_error" end)
{:error, "timeout_error"}
```

*Chain operations*

```elixir
iex> Err.and_then({:ok, 5}, fn num -> {:ok, num * 2} end)
{:ok, 10}
```

*Flatten nested results*

```elixir
iex> Err.flatten({:ok, {:ok, 1}})
{:ok, 1}
```

*Eager fallback*

```elixir
iex> Err.or_else({:error, :cache_miss}, {:ok, "disk.db"})
{:ok, "disk.db"}
```

*Lazy fallback*

```elixir
Err.or_else_lazy({:error, :cache_miss}, fn _reason ->
  {:ok, load_from_disk()}
end)
```

*Combine results (fail fast)*

```elixir
iex> Err.all([{:ok, 1}, {:ok, 2}, {:ok, 3}])
{:ok, [1, 2, 3]}

iex> Err.all([{:ok, 1}, {:error, :timeout}])
{:error, :timeout}
```

*Extract ok values*

```elixir
iex> Err.values([{:ok, 1}, {:error, :x}, {:ok, 2}])
[1, 2]
```

*Split into ok and error lists*

```elixir
iex> Err.partition([{:ok, 1}, {:error, "a"}, {:ok, 2}])
{[1, 2], ["a"]}
```

*Check if result is ok*

```elixir
def process(result) when Err.is_ok(result) do
  # handle ok
end
```

*Check if result is error*

```elixir
def process(result) when Err.is_err(result) do
  # handle error
end
```

### Real-World Example

```elixir
def fetch_user_profile(user_id) do
  user_id
  |> fetch_user()
  |> Err.and_then(&load_profile/1)
  |> Err.and_then(&enrich_with_stats/1)
  |> Err.or_else_lazy(fn _error ->
    {:ok, %{name: "Guest", stats: %{}}}
  end)
end
```
