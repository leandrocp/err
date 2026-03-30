# Err

[![Hex.pm](https://img.shields.io/hexpm/v/err.svg)](https://hex.pm/packages/err)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/err)

<!-- MDOC -->

**Error handling for Elixir. Let it flow.**

`Err` is a tiny library for composing and normalizing error flows in Elixir.

It works with the conventions Elixir developers already use:

- `{:ok, value}` and `{:error, reason}`
- `nil` as absence
- existing return values from Phoenix, Ecto, Oban, and your own code

Instead of introducing a new result type or DSL, `Err` helps turn mixed return styles into
flows that are easier to compose, transform, and reason about.

Use it to:

- compose result pipelines cleanly
- normalize `nil`, tuples, and exception-based APIs
- transform errors close to the boundary
- keep `with`-based application code readable

## Features

- Works with existing `:ok` / `:error` tuples of any size
- Treats `nil` as absence for Option-style flows
- Normalizes values into result flows with `from_nil/2` and `try_rescue/2`
- Wraps `Task` work with `async/1`, `await/2`, and `await_many/2`
- Composes success and error paths with `map/2`, `map_err/2`, `and_then/2`, and `or_else/2`
- Adds side effects without changing values using `tap/2` and `tap_err/2`
- Keeps branching explicit with `match/2`
- Includes list helpers like `all/1`, `values/1`, and `partition/1`
- Ships with exception helpers like `wrap/1` and `message/1`

## Installation

Add `err` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:err, "~> 0.2"}
  ]
end
```

## Why Err?

Elixir already has excellent primitives for error handling: pattern matching, `with`, `case`,
and tagged tuples.

The friction usually starts when application code combines several styles from several libraries:

- `Repo.get/2` returns `nil`
- `Repo.insert/2` returns `{:ok, struct}` or `{:error, changeset}`
- some APIs raise exceptions
- others return custom tuples or atoms

`Err` is a small glue layer for normalizing those differences.

## Usage

*Wrap values*

```elixir
iex> Err.ok(42)
{:ok, 42}

iex> Err.error(:timeout)
{:error, :timeout}
```

*Normalize `nil` into a result*

```elixir
iex> Err.from_nil("config.json", :not_found)
{:ok, "config.json"}

iex> Err.from_nil(nil, :not_found)
{:error, :not_found}
```

*Convert raising code into a result*

```elixir
iex> Err.try_rescue(fn -> 100 + 23 end)
{:ok, 123}

iex> Err.try_rescue(fn -> raise "boom" end) |> Err.map_err(&Exception.message/1)
{:error, "boom"}
```

*Run Task work through results*

```elixir
iex> task = Err.async(fn -> 40 + 2 end)
iex> Err.await(task)
{:ok, 42}

iex> [Task.async(fn -> 1 end), Task.async(fn -> {:error, :boom} end)] |> Err.await_many()
[{:ok, 1}, {:error, :boom}]
```

*Unwrap with defaults*

```elixir
iex> Err.unwrap_or({:ok, "config.json"}, "default.json")
"config.json"

iex> Err.unwrap_or({:error, :not_found}, "default.json")
"default.json"
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

*Add side effects without changing the result*

```elixir
iex> Err.tap({:ok, 5}, fn value -> send(self(), {:seen, value}) end)
{:ok, 5}

iex> Err.tap_err({:error, :timeout}, fn reason -> send(self(), {:seen_error, reason}) end)
{:error, :timeout}
```

*Branch explicitly at the boundary*

```elixir
iex> Err.match({:ok, 5}, ok: &(&1 * 2), error: fn _ -> 0 end)
10

iex> Err.match(nil, ok: & &1, error: fn _ -> :missing end)
:missing
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
iex> Err.or_else_lazy({:error, :cache_miss}, fn _reason -> {:ok, "disk.db"} end)
{:ok, "disk.db"}
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
  result
end
```

*Check if result is error*

```elixir
def process(result) when Err.is_err(result) do
  result
end
```

## Real-World Example

```elixir
def fetch_user_profile(id) do
  with {:ok, user} <- Repo.get(User, id) |> Err.from_nil(:not_found),
       {:ok, account} <- Accounts.fetch_account(user) |> Err.map_err(&normalize_error/1),
       {:ok, stats} <- Stats.fetch(account) |> Err.map_err(&normalize_error/1) do
    {:ok, %{user: user, account: account, stats: stats}}
  end
end
```

`Err` complements `with`, `case`, and pattern matching. It does not try to replace them.
