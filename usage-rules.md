# Err - Usage Rules for AI Agents

Err is an Elixir library providing Result and Option types inspired by Rust, offering explicit error handling without exceptions.

## When to Use Err

**Use Err when:**
- Building domain logic with explicit error states
- Chaining operations that may fail
- Working with values that may be absent (Option type)
- You want type-safe error handling in pipelines
- Converting between `{:ok, value}` and `{:error, reason}` patterns

**Don't use Err when:**
- Working with existing code that expects standard tuples (use standard pattern matching)
- The overhead of wrapping/unwrapping isn't justified
- You need traditional try/catch exception handling

## Core Types

```elixir
@type result :: tuple()  # {:ok, value} | {:error, reason}
@type option :: any() | nil
@type value :: result() | option()
```

**Important:** Err supports multi-element tuples like `{:ok, value, metadata}` and `{:error, reason, details}`.

## Common Patterns

### Creating Results and Options

```elixir
# Wrap values
Err.ok(user)           # => {:ok, user}
Err.error(:not_found)  # => {:error, :not_found}
```

### Unwrapping Values Safely

```elixir
# With defaults
Err.unwrap_or({:ok, config}, default_config)  # => config
Err.unwrap_or({:error, _}, default_config)    # => default_config

# With exceptions (let it crash when a value is expected)
Err.expect!({:ok, user}, RuntimeError.exception("user required")) # => user
Err.expect!({:error, _}, RuntimeError.exception("user required")) # raises exception
```

### Transforming Values

```elixir
# Transform success values
{:ok, 5} |> Err.map(fn x -> x * 2 end)  # => {:ok, 10}

# Chain operations (value is extracted and passed to function)
{:ok, user}
|> Err.and_then(fn user -> fetch_permissions(user) end)
|> Err.and_then(fn perms -> validate_access(perms) end)

# Transform errors
{:error, :timeout}
|> Err.map_err(fn _ -> :network_error end)  # => {:error, :network_error}
```

### Working with Lists

```elixir
# Combine results (fail-fast)
Err.all([{:ok, 1}, {:ok, 2}])  # => {:ok, [1, 2]}
Err.all([{:ok, 1}, {:error, :x}])  # => {:error, :x}

# Extract only success values
Err.values([{:ok, 1}, {:error, :x}, {:ok, 2}])  # => [1, 2]

# Partition into successes and failures
Err.partition([{:ok, 1}, {:error, "a"}, {:ok, 2}])  # => {[1, 2], ["a"]}
```

### Guards for Pattern Matching

```elixir
import Err

def process(result) when is_ok(result), do: # handle success
def process(result) when is_err(result), do: # handle error
def process(value) when is_some(value), do: # handle non-nil
```

## Multi-Element Tuples

Err handles tuples with metadata by extracting/returning values as lists:

```elixir
# Two-element tuple returns the value directly
Err.unwrap_or({:ok, user}, nil)  # => user

# Multi-element tuple returns remaining elements as list
Err.unwrap_or({:ok, user, :cached}, nil)  # => [user, :cached]

# Works consistently across all functions
Err.map({:ok, x, y}, fn [val, meta] -> val * 2 end)
```

## Best Practices

### 1. Chain Operations Instead of Nesting

**Good:**
```elixir
{:ok, input}
|> Err.and_then(&validate/1)
|> Err.and_then(&transform/1)
|> Err.and_then(&save/1)
```

**Avoid:**
```elixir
case validate(input) do
  {:ok, valid} ->
    case transform(valid) do
      {:ok, transformed} -> save(transformed)
      error -> error
    end
  error -> error
end
```

### 2. Use Guards for Cleaner Code

**Good:**
```elixir
def handle(result) when is_ok(result), do: extract_value(result)
def handle(result) when is_err(result), do: handle_error(result)
```

**Avoid:**
```elixir
def handle({:ok, _} = result), do: extract_value(result)
def handle({:error, _} = result), do: handle_error(result)
```

### 3. Prefer `unwrap_or` for Safe Defaults

**Good:**
```elixir
config = Err.unwrap_or(fetch_config(), default_config())
```

**Avoid:**
```elixir
config = case fetch_config() do
  {:ok, c} -> c
  {:error, _} -> default_config()
end
```

### 4. Use `expect!` Only When Value is Expected

```elixir
user = Err.expect!(fetch_current_user(), RuntimeError.exception("user must be authenticated"))
```

### 5. Leverage `or_else` for Fallbacks

```elixir
# Try cache first, fall back to database
get_from_cache(key)
|> Err.or_else(get_from_database(key))
```

### 6. Use Type-Specific Functions

```elixir
# For Results: map/2, map_err/2, and_then/2
# For Options: map/2 (treats nil as None)
# For Lists: all/1, values/1, partition/1
```

## Common Mistakes to Avoid

### ❌ Don't ignore multi-element tuple behavior

```elixir
# Wrong - expecting a single value
{:ok, user, :cached} |> Err.map(fn u -> u.name end)  # Error! u is a list

# Right - handle list for multi-element tuples
{:ok, user, :cached} |> Err.map(fn [u, _meta] -> u.name end)
```

### ❌ Don't use Err.ok/error unnecessarily

```elixir
# Wrong - already a result tuple
result = {:ok, value}
wrapped = Err.ok(result)  # => {:ok, {:ok, value}}

# Right - use as-is or flatten if nested
result = {:ok, value}  # Good
Err.flatten({:ok, {:ok, value}})  # If you have nesting
```

### ❌ Don't mix exception-based and Result-based error handling

```elixir
# Wrong - mixing paradigms
def process(input) do
  case validate(input) do
    {:ok, valid} ->
      try do
        transform(valid)  # May raise
      rescue
        e -> {:error, e}
      end
    error -> error
  end
end

# Right - be consistent
def process(input) do
  {:ok, input}
  |> Err.and_then(&validate/1)
  |> Err.and_then(&transform/1)
end
```

### ❌ Don't use `and_then` when `map` is sufficient

```elixir
# Wrong - unnecessary wrapping
{:ok, 5} |> Err.and_then(fn x -> {:ok, x * 2} end)

# Right - use map when you're just transforming
{:ok, 5} |> Err.map(fn x -> x * 2 end)
```

## Function Quick Reference

| Function | Purpose | Example |
|----------|---------|---------|
| `ok/1`, `error/1` | Wrap values | `Err.ok(user)` |
| `unwrap_or/2` | Extract value with default | `unwrap_or({:ok, x}, 0)` |
| `expect!/2` | Extract or raise | `expect!({:ok, x}, Error.exception("msg"))` |
| `map/2` | Transform success value | `map({:ok, x}, &(&1 * 2))` |
| `map_err/2` | Transform error | `map_err({:error, x}, &to_string/1)` |
| `and_then/2` | Chain operations | `and_then({:ok, x}, &process/1)` |
| `all/1` | Combine results (fail-fast) | `all([{:ok, 1}, {:ok, 2}])` |
| `values/1` | Extract success values | `values([{:ok, 1}, {:error, 2}])` |
| `partition/1` | Split into ok/error lists | `partition([{:ok, 1}, {:error, 2}])` |
| `is_ok/1`, `is_err/1` | Guards for pattern matching | `when is_ok(result)` |
| `flatten/1` | Flatten nested results | `flatten({:ok, {:ok, x}})` |

## Summary

Err provides functional error handling for Elixir. Use it to make error states explicit, chain operations safely, and avoid exception-based control flow. The library shines when building composable domain logic with clear success/failure paths.
