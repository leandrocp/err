# Err

## Project Overview

Err is a tiny Elixir library for standardizing error handling and provide utilities for working with ok/error tuples.

Inspired by:
- [Rust Result](https://doc.rust-lang.org/std/result/enum.Result.html)
- [Rust Options](https://doc.rust-lang.org/std/option/enum.Option.html)
- [Glean Result](https://hexdocs.pm/gleam_stdlib/gleam/result.html)
- [Glean Option](https://hexdocs.pm/gleam_stdlib/gleam/option.html)

### Result

Any tuple with first value being `:ok` or `:error` is considered a Result.

```elixir
{:ok, 1}
{:ok, [1, 2, 3]}
{:ok, 1, %{source: :user}}
{:error, :not_found}
{:error, "Something went wrong", %{system: :db}}
```

It does work with tuples of any size, but for simplicity it extracts single values when the tuple size is 2 like `{:ok, value}` or `{:error, reason}`
or extracts a list when there are more than 2 elements like `{:ok, value1, value2}` or `{:error, reason, meta}`.

```elixir
# extract rules
{:ok, 1}                     #=> 1
{:ok, 1, %{source: :user}}   #=> [1, %{source: :user}]
{:error, :not_found}         #=> :not_found
{:error, "Something went wrong", %{system: :db}} #=> ["Something went wrong", %{system: :db}]
```

### Option

Any `nil` value is considered None, any other value is Some.

```elixir
"Hello" #=> Some
nil     #=> None
```

### Eager vs Lazy

Functions suffixed with `_lazy` expect a function as an argument and will only call it when needed,
others will return it as-is even if it's a function.

```elixirelixir
Err.unwrap_or_else({:error, 1}, fn -> 2 end) #=> #Function<42.113135111/1 in :erl_eval.expr/6>
Err.unwrap_or_else_lazy({:error, 1}, fn val -> val + 1 end) #=> 2
```

### Constraints

- It does not introduce new data structures or structs. It works with existing Elixir conventions of `{:ok, value}` and `{:error, reason}` tuples.
- No complex DSL, just functions.
- No hard to understand pipes as `~~>` or any other, just functions.
- Not even a single `warning: incompatible types` is allowed.
- Run `mix test` to validate the library.
- Run `mix compile --all-warmings` to valid the codebase.

## Changelog
- Follow the https://common-changelog.org format
- Create a "## Unreleased" section if it doesn't exist yet
- Add new entries into the "## Unreleased" section
- Short and concise descriptions
- Review existing entries for accuracy and clarity
- Fetch commits from latest release tag to HEAD
