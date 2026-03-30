defmodule Err do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.fetch!(1)

  @typedoc """
  A result type representing either success or failure.

  Can be:
  - `{:ok, value}` - A successful result with a value
  - `{:error, error}` - A failed result with an error
  - Any tuple starting with `:ok` or `:error` (supports multiple elements)
  """
  @type result :: tuple()

  @typedoc """
  An option type representing either some value or none.

  Can be:
  - `value` - Some value is present
  - `nil` - No value (none)
  """
  @type option :: any() | nil

  @typedoc """
  Either a `t:result/0` or an `t:option/0` type.
  """
  @type value :: result() | option()

  @doc """
  Wraps `value` in an `{:ok, value}` tuple.

  ## Examples

      iex> Err.ok(%{id: 1, email: "john@example.com"})
      {:ok, %{email: "john@example.com", id: 1}}

      iex> Err.ok({:ok, 100})
      {:ok, {:ok, 100}}

  """
  @spec ok(any()) :: result()
  def ok(value), do: {:ok, value}

  @doc """
  Wraps `value` in an `{:error, value}` tuple.

  ## Examples

      iex> Err.error(:timeout)
      {:error, :timeout}

      iex> Err.error({:validation_failed, :email})
      {:error, {:validation_failed, :email}}

  """
  @spec error(any()) :: result()
  def error(value), do: {:error, value}

  @doc """
  Normalizes a nullable value into a result.

  Returns `{:ok, value}` for any non-`nil` value. Returns `{:error, reason}` when the value is
  `nil`. Existing result tuples are returned unchanged.

  This is useful for adapting APIs such as `Repo.get/2` that return `nil` on absence into flows
  that work naturally with `with`, `map_err/2`, and `or_else/2`.

  ## Examples

      iex> Err.from_nil("config.json", :not_found)
      {:ok, "config.json"}

      iex> Err.from_nil(nil, :not_found)
      {:error, :not_found}

      iex> Err.from_nil({:ok, 1}, :not_found)
      {:ok, 1}

      iex> Err.from_nil({:error, :timeout}, :not_found)
      {:error, :timeout}

  """
  @spec from_nil(value(), any()) :: result()
  def from_nil(value, error)
  def from_nil(nil, error), do: {:error, error}
  def from_nil({:ok, _} = ok, _error), do: ok
  def from_nil({:error, _} = error, _fallback), do: error

  def from_nil(tuple, _error) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> tuple
      :error -> tuple
      _ -> {:ok, tuple}
    end
  end

  def from_nil(other, _error), do: {:ok, other}

  @doc """
  Calls `fun` with the success value and returns the original value unchanged.

  This is useful for logging, tracing, or other side effects in a flow without changing the
  wrapped value.

  ## Examples

      iex> Err.tap({:ok, 5}, fn value -> send(self(), {:seen, value}) end)
      {:ok, 5}

      iex> Err.tap({:error, :timeout}, fn _ -> raise "should not run" end)
      {:error, :timeout}

      iex> Err.tap(nil, fn _ -> raise "should not run" end)
      nil

  """
  @spec tap(value(), (any() -> any())) :: value()
  def tap(value, fun)
  def tap(nil, _fun), do: nil

  def tap({:ok, value} = ok, fun) do
    fun.(value)
    ok
  end

  def tap({:error, _} = error, _fun), do: error

  def tap(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        fun.(result_payload(tuple))
        tuple

      :error ->
        tuple

      _ ->
        fun.(tuple)
        tuple
    end
  end

  def tap(other, fun) do
    fun.(other)
    other
  end

  @doc """
  Calls `fun` with the error value and returns the original value unchanged.

  This is useful for logging, tracing, or metrics on error paths without changing the error.

  ## Examples

      iex> Err.tap_err({:error, :timeout}, fn reason -> send(self(), {:seen_error, reason}) end)
      {:error, :timeout}

      iex> Err.tap_err({:ok, 5}, fn _ -> raise "should not run" end)
      {:ok, 5}

      iex> Err.tap_err(nil, fn _ -> raise "should not run" end)
      nil

  """
  @spec tap_err(value(), (any() -> any())) :: value()
  def tap_err(value, fun)
  def tap_err(nil, _fun), do: nil
  def tap_err({:ok, _} = ok, _fun), do: ok

  def tap_err({:error, reason} = error, fun) do
    fun.(reason)
    error
  end

  def tap_err(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :error ->
        fun.(result_payload(tuple))
        tuple

      _ ->
        tuple
    end
  end

  def tap_err(other, _fun), do: other

  @doc """
  Executes `fun` and converts rescued exceptions into an error result.

  Returns `{:ok, value}` when the function succeeds. If the function raises, returns
  `{:error, exception}` by default or `{:error, mapper.(exception)}` when a mapper is provided.

  This is useful at library boundaries where a raising API needs to be adapted into a result flow.

  ## Examples

      iex> Err.try_rescue(fn -> 100 + 23 end)
      {:ok, 123}

      iex> Err.try_rescue(fn -> raise "boom" end) |> Err.map_err(&Exception.message/1)
      {:error, "boom"}

      iex> Err.try_rescue(fn -> raise "boom" end, fn error -> %{kind: :runtime_error, message: Exception.message(error)} end)
      {:error, %{kind: :runtime_error, message: "boom"}}

  """
  @spec try_rescue((-> any())) :: result()
  @spec try_rescue((-> any()), (Exception.t() -> any())) :: result()
  def try_rescue(fun, rescue_fun \\ fn error -> error end) when is_function(fun, 0) do
    {:ok, fun.()}
  rescue
    error -> {:error, rescue_fun.(error)}
  end

  @doc """
  Starts a task and normalizes its return value into a result.

  Plain values are wrapped as `{:ok, value}`. Existing result tuples are returned unchanged.
  Rescued exceptions become `{:error, exception}`. Throws and exits are returned as tagged errors.

  This is useful when adapting `Task`-based work into the same result flow used by synchronous
  code.

  ## Examples

      iex> task = Err.async(fn -> 40 + 2 end)
      iex> Err.await(task)
      {:ok, 42}

      iex> task = Err.async(fn -> {:ok, :cached} end)
      iex> Err.await(task)
      {:ok, :cached}

      iex> task = Err.async(fn -> raise "boom" end)
      iex> Err.await(task) |> Err.map_err(&Exception.message/1)
      {:error, "boom"}

  """
  @spec async((-> any())) :: Task.t()
  def async(fun) when is_function(fun, 0) do
    Task.async(fn ->
      try do
        normalize_result(fun.())
      rescue
        error -> {:error, error}
      catch
        :exit, reason -> {:error, {:exit, reason}}
        :throw, reason -> {:error, {:throw, reason}}
      end
    end)
  end

  @doc """
  Awaits a task and converts its outcome into a result without exiting the caller.

  Plain task replies are wrapped as `{:ok, value}`. Existing result tuples are returned unchanged.
  If the task exits, returns `{:error, {:exit, reason}}`. If the timeout is reached, the task is
  shut down and `{:error, :timeout}` is returned.

  ## Examples

      iex> Task.async(fn -> 21 * 2 end) |> Err.await()
      {:ok, 42}

      iex> Task.async(fn -> {:error, :not_found} end) |> Err.await()
      {:error, :not_found}

  """
  @spec await(Task.t(), timeout()) :: result()
  def await(task, timeout \\ 5000) do
    task
    |> Task.yield(timeout)
    |> fallback_task_result(task)
    |> normalize_task_reply()
  end

  @doc """
  Awaits multiple tasks and converts each outcome into a result without exiting the caller.

  Results are returned in the same order as the input tasks. Each reply follows the same
  normalization rules as `await/2`.

  ## Examples

      iex> [Task.async(fn -> 1 end), Task.async(fn -> {:error, :boom} end)] |> Err.await_many()
      [{:ok, 1}, {:error, :boom}]

  """
  @spec await_many([Task.t()], timeout()) :: [result()]
  def await_many(tasks, timeout \\ 5000) do
    tasks
    |> Task.yield_many(timeout: timeout)
    |> Enum.map(fn {task, reply} ->
      reply
      |> fallback_task_result(task)
      |> normalize_task_reply()
    end)
  end

  @doc """
  Returns the wrapped `value` or `default` when the result is error or value is empty.

  For two-element result tuples (`{:ok, value}`) it returns `value`. When the tuple
  contains additional metadata, it returns the remaining elements as a list.

  Accepts `nil`, any `{:ok, value}` or `{:error, reason}` tuple (with or without extra metadata),
  and other terms.

  ## Examples

      iex> Err.unwrap_or({:ok, "config.json"}, "default.json")
      "config.json"

      iex> Err.unwrap_or({:ok, :user, %{role: :admin}}, [])
      [:user, %{role: :admin}]

      iex> Err.unwrap_or({:error, :not_found}, "default.json")
      "default.json"

      iex> Err.unwrap_or(nil, "default.json")
      "default.json"

  """
  @spec unwrap_or(value(), any()) :: any()
  def unwrap_or(value, default)
  def unwrap_or(nil, default), do: default
  def unwrap_or({:ok, value}, _default), do: value
  def unwrap_or({:error, _}, default), do: default

  def unwrap_or(tuple, default) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> tuple |> Tuple.delete_at(0) |> Tuple.to_list()
      :error -> default
      _ -> tuple
    end
  end

  def unwrap_or(other, _default), do: other

  @doc """
  Returns the wrapped value or computes it from `default_fun` when the result is an error or value
  is empty.

  For successful tuples (`{:ok, value}`) the unwrapped value is returned. When the tuple contains
  extra data, the remaining elements are returned as a list. For error tuples the extracted value(s)
  are passed to `default_fun`.

  The function receives the extracted value(s): a single value for two-element tuples or a list for
  larger tuples.

  This is the lazy version of `unwrap_or/2` - the function is only called when needed.

  ## Examples

      iex> Err.unwrap_or_lazy({:ok, "config.json"}, fn _ -> "default.json" end)
      "config.json"

      iex> Err.unwrap_or_lazy({:ok, :admin, %{perms: [:read]}}, fn _ -> [] end)
      [:admin, %{perms: [:read]}]

      iex> Err.unwrap_or_lazy({:error, :enoent}, fn reason -> "Error: \#{reason}" end)
      "Error: enoent"

      iex> Err.unwrap_or_lazy(nil, fn _ -> %{role: :guest} end)
      %{role: :guest}

  """
  @spec unwrap_or_lazy(value(), (any() -> any())) :: any()
  def unwrap_or_lazy(nil, default_fun), do: default_fun.([])
  def unwrap_or_lazy({:ok, value}, _default_fun), do: value
  def unwrap_or_lazy({:error, reason}, default_fun), do: default_fun.(reason)

  def unwrap_or_lazy(tuple, default_fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        tuple |> Tuple.delete_at(0) |> Tuple.to_list()

      :error ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        default_fun.(payload)

      _ ->
        tuple
    end
  end

  def unwrap_or_lazy(other, _default_fun), do: other

  @doc """
  Returns the wrapped error or `default` when the result is ok or value is present.

  For two-element error tuples (`{:error, reason}`) it returns `reason`. When the tuple contains
  additional metadata, it returns the remaining elements as a list.

  Accepts `nil`, any `{:ok, value}` or `{:error, reason}` tuple (with or without extra metadata),
  and other terms.

  ## Examples

      iex> Err.unwrap_err_or({:error, :timeout}, :no_error)
      :timeout

      iex> Err.unwrap_err_or({:error, :boom, %{code: 500}}, :no_error)
      [:boom, %{code: 500}]

      iex> Err.unwrap_err_or({:ok, 1}, :no_error)
      :no_error

      iex> Err.unwrap_err_or(nil, :no_error)
      :no_error

  """
  @spec unwrap_err_or(value(), any()) :: any()
  def unwrap_err_or(value, default)
  def unwrap_err_or(nil, default), do: default
  def unwrap_err_or({:ok, _}, default), do: default
  def unwrap_err_or({:error, reason}, _default), do: reason

  def unwrap_err_or(tuple, default) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> default
      :error -> tuple |> Tuple.delete_at(0) |> Tuple.to_list()
      _ -> default
    end
  end

  def unwrap_err_or(_other, default), do: default

  @doc """
  Returns the wrapped value from an `{:ok, value}` tuple or raises the provided exception.

  For two-element result tuples (`{:ok, value}`) it returns `value`. When the tuple contains
  additional metadata, it returns the remaining elements as a list.

  If the value is `{:error, _}`, `nil`, or any other value, raises the provided exception.

  ## Examples

      iex> Err.expect!({:ok, "config.json"}, RuntimeError.exception("config not found"))
      "config.json"

      iex> Err.expect!({:ok, :user, %{role: :admin}}, RuntimeError.exception("user not found"))
      [:user, %{role: :admin}]

  """
  @spec expect!(value(), Exception.t()) :: any()
  def expect!(value, exception)

  def expect!({:ok, value}, _exception), do: value

  def expect!(tuple, exception) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> tuple |> Tuple.delete_at(0) |> Tuple.to_list()
      _ -> raise exception
    end
  end

  def expect!(_value, exception), do: raise(exception)

  @doc """
  Returns the wrapped error from an `{:error, reason}` tuple or raises the provided exception.

  For two-element error tuples (`{:error, reason}`) it returns `reason`. When the tuple contains
  additional metadata, it returns the remaining elements as a list.

  If the value is `{:ok, _}`, `nil`, or any other value, raises the provided exception.

  ## Examples

      iex> Err.expect_err!({:error, :timeout}, RuntimeError.exception("expected an error"))
      :timeout

      iex> Err.expect_err!({:error, 404, "Not Found"}, RuntimeError.exception("expected an error"))
      [404, "Not Found"]

  """
  @spec expect_err!(value(), Exception.t()) :: any()
  def expect_err!(value, exception)

  def expect_err!({:error, reason}, _exception), do: reason

  def expect_err!(tuple, exception) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :error -> tuple |> Tuple.delete_at(0) |> Tuple.to_list()
      _ -> raise exception
    end
  end

  def expect_err!(_value, exception), do: raise(exception)

  @doc """
  Chains the result by calling `fun` when the value is present.

  For `{:ok, value}` the extracted value (or list of values) is passed to `fun`.
  Error tuples and `nil` are returned unchanged, allowing the pipeline to short-circuit.

  ## Examples

      iex> Err.and_then({:ok, 5}, fn num -> num * 2 end)
      10

      iex> Err.and_then(5, fn num -> num * 2 end)
      10

      iex> Err.and_then({:ok, :admin, %{id: 1}}, fn [role, user] -> {:ok, %{role: role, user_id: user.id}} end)
      {:ok, %{role: :admin, user_id: 1}}

      iex> Err.and_then({:error, :timeout}, fn num -> {:ok, num * 2} end)
      {:error, :timeout}

      iex> Err.and_then(nil, fn value -> {:ok, value} end)
      nil

  """
  @spec and_then(value(), (any() -> any())) :: any()
  def and_then(value, fun)
  def and_then(nil, _fun), do: nil
  def and_then({:ok, value}, fun), do: fun.(value)
  def and_then({:error, _} = error, _fun), do: error

  def and_then(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        fun.(payload)

      :error ->
        tuple

      _ ->
        fun.(tuple)
    end
  end

  def and_then(other, fun), do: fun.(other)

  @doc """
  Transforms the success value inside an `{:ok, value}` tuple or some value by applying a function to it.

  For Result types (`{:ok, value}` or `{:error, reason}`), applies the function to the value
  if it's `{:ok, _}`, otherwise returns the error unchanged.

  For Option types (`nil` or any value), applies the function to the value if it's not `nil`,
  otherwise returns `nil`.

  ## Examples

      iex> Err.map({:ok, 5}, fn num -> num * 2 end)
      {:ok, 10}

      iex> Err.map({:ok, "hello"}, &String.upcase/1)
      {:ok, "HELLO"}

      iex> Err.map({:error, :timeout}, fn num -> num * 2 end)
      {:error, :timeout}

      iex> Err.map(nil, fn num -> num * 2 end)
      nil

      iex> Err.map("hello", &String.upcase/1)
      "HELLO"

  """
  @spec map(value(), (any() -> any())) :: value()
  def map(value, fun)
  def map(nil, _fun), do: nil
  def map({:ok, value}, fun), do: {:ok, fun.(value)}
  def map({:error, _} = error, _fun), do: error

  def map(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        List.to_tuple([:ok, fun.(payload)])

      :error ->
        tuple

      _ ->
        fun.(tuple)
    end
  end

  def map(other, fun), do: fun.(other)

  @doc """
  Matches on success/presence and error/absence with explicit handlers.

  Existing result tuples dispatch to `:ok` or `:error`. `nil` dispatches to `:error`. Any other
  non-`nil` value dispatches to `:ok`.

  ## Examples

      iex> Err.match({:ok, 5}, ok: &(&1 * 2), error: fn _ -> 0 end)
      10

      iex> Err.match({:error, :timeout}, ok: & &1, error: &inspect/1)
      ":timeout"

      iex> Err.match(nil, ok: & &1, error: fn _ -> :missing end)
      :missing

      iex> Err.match("value", ok: &String.upcase/1, error: fn _ -> :missing end)
      "VALUE"

  """
  @spec match(value(), ok: (any() -> any()), error: (any() -> any())) :: any()
  def match(value, handlers) when is_list(handlers) do
    ok_fun = Keyword.fetch!(handlers, :ok)
    error_fun = Keyword.fetch!(handlers, :error)

    case value do
      nil ->
        error_fun.(nil)

      {:ok, payload} ->
        ok_fun.(payload)

      {:error, reason} ->
        error_fun.(reason)

      tuple when is_tuple(tuple) ->
        case elem(tuple, 0) do
          :ok -> ok_fun.(result_payload(tuple))
          :error -> error_fun.(result_payload(tuple))
          _ -> ok_fun.(tuple)
        end

      other ->
        ok_fun.(other)
    end
  end

  @doc """
  Transforms the error inside an `{:error, reason}` tuple by applying a function to it.

  For Result types (`{:ok, value}` or `{:error, reason}`), applies the function to the error
  if it's `{:error, _}`, otherwise returns the ok tuple unchanged.

  Ignores `nil` and non-Result values, returning them unchanged.

  ## Examples

      iex> Err.map_err({:error, 404}, fn code -> "HTTP \#{code}" end)
      {:error, "HTTP 404"}

      iex> Err.map_err({:ok, "success"}, fn reason -> "\#{reason}_error" end)
      {:ok, "success"}

      iex> Err.map_err(nil, fn reason -> "\#{reason}_error" end)
      nil

      iex> Err.map_err(404, fn reason -> "\#{reason}_error" end)
      404

  """
  @spec map_err(value(), (any() -> any())) :: value()
  def map_err(value, fun)
  def map_err(nil, _fun), do: nil
  def map_err({:ok, _} = ok, _fun), do: ok
  def map_err({:error, reason}, fun), do: {:error, fun.(reason)}

  def map_err(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        tuple

      :error ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        List.to_tuple([:error, fun.(payload)])

      _ ->
        tuple
    end
  end

  def map_err(other, _fun), do: other

  @doc """
  Ensures the value satisfies `predicate`, otherwise returns `{:error, error}`.

  Existing error tuples are returned unchanged. For successful result tuples the extracted value
  (or list of values) is passed to `predicate`. For plain values and option-style values, a truthy
  predicate keeps the original value and a falsy predicate returns `{:error, error}`.

  ## Examples

      iex> Err.ensure({:ok, 10}, &(&1 > 5), :too_small)
      {:ok, 10}

      iex> Err.ensure({:ok, 3}, &(&1 > 5), :too_small)
      {:error, :too_small}

      iex> Err.ensure({:error, :timeout}, &(&1 > 5), :too_small)
      {:error, :timeout}

      iex> Err.ensure("hello", &(String.length(&1) > 3), :too_short)
      "hello"

      iex> Err.ensure(nil, & &1, :missing)
      {:error, :missing}

  """
  @spec ensure(value(), (any() -> any()), any()) :: value()
  def ensure(value, predicate, error)
  def ensure(nil, _predicate, error), do: {:error, error}

  def ensure({:ok, value} = ok, predicate, error) do
    if predicate.(value), do: ok, else: {:error, error}
  end

  def ensure({:error, _} = result, _predicate, _error), do: result

  def ensure(tuple, predicate, error) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> if predicate.(result_payload(tuple)), do: tuple, else: {:error, error}
      :error -> tuple
      _ -> if predicate.(tuple), do: tuple, else: {:error, error}
    end
  end

  def ensure(other, predicate, error) do
    if predicate.(other), do: other, else: {:error, error}
  end

  @doc """
  Checks if a value is an `{:ok, ...}` result tuple.

  Returns `true` for any tuple starting with `:ok`, `false` otherwise.

  Allowed in guard tests.

  ## Examples

      iex> Err.is_ok({:ok, 1})
      true

      iex> Err.is_ok({:ok, 1, 2})
      true

      iex> Err.is_ok({:error, :timeout})
      false

      iex> Err.is_ok(nil)
      false

      iex> Err.is_ok("value")
      false

      def my_function(result) when is_ok(result)

  """
  @spec is_ok(any()) :: boolean()
  defguard is_ok(value) when is_tuple(value) and tuple_size(value) >= 2 and elem(value, 0) == :ok

  @doc """
  Checks if a value is an `{:error, ...}` result tuple.

  Returns `true` for any tuple starting with `:error`, `false` otherwise.

  Allowed in guard tests.

  ## Examples

      iex> Err.is_err({:error, :timeout})
      true

      iex> Err.is_err({:error, 404, "Not Found"})
      true

      iex> Err.is_err({:ok, 1})
      false

      iex> Err.is_err(nil)
      false

      iex> Err.is_err("error")
      false

      def my_function(result) when is_err(result)

  """
  @spec is_err(any()) :: boolean()
  defguard is_err(value)
           when is_tuple(value) and tuple_size(value) >= 2 and elem(value, 0) == :error

  @doc """
  Checks if a value is "some" (not `nil`).

  Returns `true` for any value except `nil`.

  Allowed in guard tests.

  ## Examples

      iex> Err.is_some(1)
      true

      iex> Err.is_some("hello")
      true

      iex> Err.is_some({:ok, 1})
      true

      iex> Err.is_some(false)
      true

      iex> Err.is_some(nil)
      false

      def my_function(value) when is_some(value)

  """
  @spec is_some(any()) :: boolean()
  defguard is_some(value) when value != nil

  @doc """
  Checks if a value is none (`nil`).

  Returns `true` only for `nil`.

  Allowed in guard tests.

  ## Examples

      iex> Err.is_none(nil)
      true

      iex> Err.is_none(1)
      false

      iex> Err.is_none({:ok, 1})
      false

      def my_function(value) when Err.is_none(value)

  """
  @spec is_none(any()) :: boolean()
  defguard is_none(value) when value == nil

  @doc """
  Returns `true` when the value is an ok result and its payload satisfies `predicate`.

  Returns `false` for non-ok values without calling `predicate`.

  ## Examples

      iex> Err.ok_and?({:ok, 10}, &(&1 > 5))
      true

      iex> Err.ok_and?({:ok, 3}, &(&1 > 5))
      false

      iex> Err.ok_and?({:error, :timeout}, &(&1 > 5))
      false

  """
  @spec ok_and?(any(), (any() -> any())) :: boolean()
  def ok_and?(value, predicate)
  def ok_and?({:ok, payload}, predicate), do: !!predicate.(payload)

  def ok_and?(tuple, predicate) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> !!predicate.(result_payload(tuple))
      _ -> false
    end
  end

  def ok_and?(_other, _predicate), do: false

  @doc """
  Returns `true` when the value is an error result and its payload satisfies `predicate`.

  Returns `false` for non-error values without calling `predicate`.

  ## Examples

      iex> Err.err_and?({:error, :timeout}, &(&1 == :timeout))
      true

      iex> Err.err_and?({:error, :boom}, &(&1 == :timeout))
      false

      iex> Err.err_and?({:ok, 1}, &(&1 == :timeout))
      false

  """
  @spec err_and?(any(), (any() -> any())) :: boolean()
  def err_and?(value, predicate)
  def err_and?({:error, reason}, predicate), do: !!predicate.(reason)

  def err_and?(tuple, predicate) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :error -> !!predicate.(result_payload(tuple))
      _ -> false
    end
  end

  def err_and?(_other, _predicate), do: false

  @doc """
  Returns `true` when the value is present and satisfies `predicate`.

  Returns `false` for `nil` without calling `predicate`.

  ## Examples

      iex> Err.some_and?("hello", &(String.length(&1) > 3))
      true

      iex> Err.some_and?("hi", &(String.length(&1) > 3))
      false

      iex> Err.some_and?(nil, &(String.length(&1) > 3))
      false

  """
  @spec some_and?(any(), (any() -> any())) :: boolean()
  def some_and?(value, predicate)
  def some_and?(nil, _predicate), do: false
  def some_and?(other, predicate), do: !!predicate.(other)

  @doc """
  Flattens a nested result into a single layer.

  If the outer result is `{:ok, inner}` and inner is also a result tuple,
  returns the inner result. Otherwise returns the value unchanged.

  ## Examples

      iex> Err.flatten({:ok, {:ok, 1}})
      {:ok, 1}

      iex> Err.flatten({:ok, {:ok, 1, :meta}})
      {:ok, 1, :meta}

      iex> Err.flatten({:ok, {:error, :timeout}})
      {:error, :timeout}

      iex> Err.flatten({:error, :failed})
      {:error, :failed}

      iex> Err.flatten({:ok, "value"})
      {:ok, "value"}

  """
  @spec flatten(value()) :: result()
  def flatten(value)
  def flatten({:ok, {:ok, _} = inner}), do: inner
  def flatten({:ok, {:error, _} = inner}), do: inner

  def flatten({:ok, inner} = outer) when is_tuple(inner) do
    case elem(inner, 0) do
      :ok -> inner
      :error -> inner
      _ -> outer
    end
  end

  def flatten(other), do: other

  @doc """
  Returns the second value if the first one is successful/present.

  For Result types (`{:ok, value}` or `{:error, reason}`), returns the second value if the first
  is `{:ok, _}`, otherwise returns the first error unchanged.

  For Option types (`nil` or any value), returns the second value if the first is not `nil`,
  otherwise returns `nil`.

  ## Examples

      iex> Err.followed_by({:ok, 1}, {:ok, 2})
      {:ok, 2}

      iex> Err.followed_by({:ok, 1}, {:error, :boom})
      {:error, :boom}

      iex> Err.followed_by({:error, :timeout}, {:ok, 2})
      {:error, :timeout}

      iex> Err.followed_by("primary", "secondary")
      "secondary"

      iex> Err.followed_by(nil, "secondary")
      nil

  """
  @spec followed_by(value(), value()) :: value()
  def followed_by(first, second)
  def followed_by(nil, _second), do: nil
  def followed_by({:ok, _}, second), do: second
  def followed_by({:error, _} = first, _second), do: first

  def followed_by(tuple, second) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> second
      :error -> tuple
      _ -> second
    end
  end

  def followed_by(_first, second), do: second

  @doc """
  Combines two successful/present values into a pair.

  For Result types, returns the first error encountered. When both values are ok, their extracted
  payloads are returned inside `{:ok, {left, right}}`.

  For Option types, returns `{left, right}` when both values are present. If either side is `nil`,
  returns `nil`.

  ## Examples

      iex> Err.zip({:ok, 1}, {:ok, 2})
      {:ok, {1, 2}}

      iex> Err.zip({:ok, :user, %{id: 1}}, {:ok, :admin})
      {:ok, {[:user, %{id: 1}], :admin}}

      iex> Err.zip({:error, :timeout}, {:ok, 2})
      {:error, :timeout}

      iex> Err.zip("left", "right")
      {"left", "right"}

      iex> Err.zip(nil, "right")
      nil

  """
  @spec zip(value(), value()) :: value()
  def zip(left, right)
  def zip(nil, _right), do: nil
  def zip(_left, nil), do: nil
  def zip({:error, _} = error, _right), do: error
  def zip(_left, {:error, _} = error), do: error
  def zip({:ok, left}, {:ok, right}), do: {:ok, {left, right}}

  def zip(left, right) when is_tuple(left) and is_tuple(right) do
    case {elem(left, 0), elem(right, 0)} do
      {:error, _} -> left
      {_, :error} -> right
      {:ok, :ok} -> {:ok, {result_payload(left), result_payload(right)}}
      {:ok, _} -> {:ok, {result_payload(left), right}}
      {_, :ok} -> {:ok, {left, result_payload(right)}}
      _ -> {left, right}
    end
  end

  def zip({:ok, left}, right), do: {:ok, {left, right}}
  def zip(left, {:ok, right}), do: {:ok, {left, right}}
  def zip(left, right), do: {left, right}

  @doc """
  Combines a list of values into a single result.

  - If all values are `{:ok, value}`, returns `{:ok, list_of_values}`.
  - If any value is an error, returns the first error encountered (fail fast).
  - If any value is `nil`, returns `nil`

  ## Examples

      iex> Err.all([{:ok, 1}, {:ok, 2}, {:ok, 3}])
      {:ok, [1, 2, 3]}

      iex> Err.all([{:ok, 1}, {:error, :timeout}, {:ok, 3}])
      {:error, :timeout}

      iex> Err.all([{:ok, 1}, nil, {:ok, 3}])
      nil

      iex> Err.all([])
      {:ok, []}

      iex> Err.all([{:ok, "a"}, {:ok, "b"}])
      {:ok, ["a", "b"]}

  """
  @spec all([value()]) :: value()
  def all(values) do
    all_impl(values, [])
  end

  defp all_impl([], acc), do: {:ok, Enum.reverse(acc)}

  defp all_impl([nil | _], _acc), do: nil

  defp all_impl([{:ok, value} | rest], acc) do
    all_impl(rest, [value | acc])
  end

  defp all_impl([{:error, _} = error | _], _acc), do: error

  defp all_impl([tuple | rest], acc) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        all_impl(rest, [payload | acc])

      :error ->
        tuple

      _ ->
        all_impl(rest, [tuple | acc])
    end
  end

  defp all_impl([value | rest], acc) do
    all_impl(rest, [value | acc])
  end

  @doc """
  Extracts all success values from a list of results.

  Returns a list containing all values, except `{:error, _}` tuples or `nil`.

  ## Examples

      iex> Err.values([{:ok, 1}, {:error, :timeout}, {:ok, 2}])
      [1, 2]

      iex> Err.values([{:ok, 1}, nil, 2])
      [1, 2]

      iex> Err.values([{:ok, "a"}, {:ok, "b"}])
      ["a", "b"]

      iex> Err.values([{:error, :x}, {:error, :y}])
      []

      iex> Err.values([1])
      [1]

      iex> Err.values([])
      []

  """
  @spec values([value()]) :: list()
  def values(results) do
    values_impl(results, [])
  end

  defp values_impl([], acc), do: Enum.reverse(acc)

  defp values_impl([nil | rest], acc) do
    values_impl(rest, acc)
  end

  defp values_impl([{:ok, value} | rest], acc) do
    values_impl(rest, [value | acc])
  end

  defp values_impl([{:error, _} | rest], acc) do
    values_impl(rest, acc)
  end

  defp values_impl([tuple | rest], acc) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        values_impl(rest, [payload | acc])

      :error ->
        values_impl(rest, acc)

      _ ->
        values_impl(rest, [tuple | acc])
    end
  end

  defp values_impl([value | rest], acc) do
    values_impl(rest, [value | acc])
  end

  @doc """
  Splits a list of results into ok values and error values.

  Returns a tuple `{ok_values, error_values}` where:
  - `ok_values` contains all values from `{:ok, value}` tuples
  - `error_values` contains all values from `{:error, reason}` tuples

  Any other value is ignored.

  ## Examples

      iex> Err.partition([{:ok, 1}, {:error, "a"}, {:ok, 2}])
      {[1, 2], ["a"]}

      iex> Err.partition([1, nil])
      {[], []}

      iex> Err.partition([{:ok, "x"}, {:ok, "y"}])
      {["x", "y"], []}

      iex> Err.partition([{:error, :timeout}, {:error, :crash}])
      {[], [:timeout, :crash]}

      iex> Err.partition([])
      {[], []}

  """
  @spec partition([value()]) :: {ok_values :: any(), error_values :: any()}
  def partition(results) do
    partition_impl(results, [], [])
  end

  defp partition_impl([], ok_acc, err_acc) do
    {Enum.reverse(ok_acc), Enum.reverse(err_acc)}
  end

  defp partition_impl([{:ok, value} | rest], ok_acc, err_acc) do
    partition_impl(rest, [value | ok_acc], err_acc)
  end

  defp partition_impl([{:error, reason} | rest], ok_acc, err_acc) do
    partition_impl(rest, ok_acc, [reason | err_acc])
  end

  defp partition_impl([tuple | rest], ok_acc, err_acc) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        partition_impl(rest, [payload | ok_acc], err_acc)

      :error ->
        payload = tuple |> Tuple.delete_at(0) |> Tuple.to_list()
        partition_impl(rest, ok_acc, [payload | err_acc])

      _ ->
        partition_impl(rest, ok_acc, err_acc)
    end
  end

  defp partition_impl([_value | rest], ok_acc, err_acc) do
    partition_impl(rest, ok_acc, err_acc)
  end

  @doc """
  Replaces the value inside an `{:ok, value}` tuple with a new value.

  If the result is `{:ok, _}`, returns `{:ok, new_value}`.
  Otherwise returns the original value unchanged.

  ## Examples

      iex> Err.replace({:ok, "old"}, "new")
      {:ok, "new"}

      iex> Err.replace({:error, :timeout}, 999)
      {:error, :timeout}

      iex> Err.replace(nil, 999)
      nil

      iex> Err.replace(100, 999)
      100

  """
  @spec replace(value(), any()) :: value()
  def replace({:ok, _}, new_value), do: {:ok, new_value}
  def replace({:error, _} = error, _new_value), do: error

  def replace(tuple, new_value) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> {:ok, new_value}
      _ -> tuple
    end
  end

  def replace(other, _new_value), do: other

  @doc """
  Replaces the value inside an `{:ok, value}` tuple by calling a function.

  If the result is `{:ok, _}`, calls the function and returns `{:ok, result}`.
  Otherwise returns the original value unchanged without calling the function.

  This is the lazy version of `replace/2` - the function is only called when needed.

  ## Examples

      iex> Err.replace_lazy({:ok, 1}, fn value -> value + 1 end)
      {:ok, 2}

      iex> Err.replace_lazy({:error, :timeout}, fn value -> value + 1 end)
      {:error, :timeout}

      iex> Err.replace_lazy(nil, fn value -> value + 1 end)
      nil

  """
  @spec replace_lazy(value(), (any() -> any())) :: value()
  def replace_lazy({:ok, value}, fun), do: {:ok, fun.(value)}
  def replace_lazy({:error, _} = error, _fun), do: error

  def replace_lazy(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok ->
        value = elem(tuple, 1)
        {:ok, fun.(value)}

      _ ->
        tuple
    end
  end

  def replace_lazy(other, _fun), do: other

  @doc """
  Replaces the error inside an `{:error, reason}` tuple with a new value.

  If the result is `{:error, _}`, returns `{:error, new_error}`.
  Otherwise returns the original value unchanged.

  ## Examples

      iex> Err.replace_err({:error, :timeout}, :network_error)
      {:error, :network_error}

      iex> Err.replace_err({:error, 404}, :not_found)
      {:error, :not_found}

      iex> Err.replace_err({:ok, 1}, :error)
      {:ok, 1}

      iex> Err.replace_err(nil, :error)
      nil

  """
  @spec replace_err(value(), any()) :: value()
  def replace_err({:ok, _} = ok, _new_error), do: ok
  def replace_err({:error, _}, new_error), do: {:error, new_error}

  def replace_err(tuple, new_error) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :error -> {:error, new_error}
      _ -> tuple
    end
  end

  def replace_err(other, _new_error), do: other

  @doc """
  Replaces the error inside an `{:error, reason}` tuple by calling a function.

  If the result is `{:error, _}`, calls the function and returns `{:error, result}`.
  Otherwise returns the original value unchanged without calling the function.

  This is the lazy version of `replace_err/2` - the function is only called when needed.

  ## Examples

      iex> Err.replace_err_lazy({:error, 404}, fn value -> "Status: \#{value}" end)
      {:error, "Status: 404"}

      iex> Err.replace_err_lazy({:ok, 1}, fn _ -> :error end)
      {:ok, 1}

      iex> Err.replace_err_lazy(nil, fn _ -> :error end)
      nil

  """
  @spec replace_err_lazy(any(), (any() -> any())) :: any()
  def replace_err_lazy({:ok, _} = ok, _fun), do: ok
  def replace_err_lazy({:error, reason}, fun), do: {:error, fun.(reason)}

  def replace_err_lazy(tuple, fun) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :error ->
        reason = elem(tuple, 1)
        {:error, fun.(reason)}

      _ ->
        tuple
    end
  end

  def replace_err_lazy(other, _fun), do: other

  @doc """
  Returns the first value if it is present/successful, otherwise returns the second value.

  For Result types (`{:ok, value}` or `{:error, reason}`), returns the first value if it's `{:ok, _}`,
  otherwise returns the second value.

  For Option types (`nil` or any value), returns the first value if it's not `nil`,
  otherwise returns the second value.

  ## Examples

      iex> Err.or_else({:ok, "cache.db"}, {:ok, "disk.db"})
      {:ok, "cache.db"}

      iex> Err.or_else({:ok, "cache.db"}, {:error, :unavailable})
      {:ok, "cache.db"}

      iex> Err.or_else({:error, :cache_miss}, {:ok, "disk.db"})
      {:ok, "disk.db"}

      iex> Err.or_else({:error, :cache_miss}, {:error, :disk_full})
      {:error, :disk_full}

      iex> Err.or_else("primary", "backup")
      "primary"

      iex> Err.or_else(nil, "backup")
      "backup"

  """
  @spec or_else(value(), value()) :: value()
  def or_else(nil, second), do: second
  def or_else({:ok, _} = first, _second), do: first
  def or_else({:error, _}, second), do: second
  def or_else(first, _second), do: first

  @doc """
  Returns the first value if it is present/successful, otherwise calls the function to compute
  an alternative value.

  For Result types (`{:ok, value}` or `{:error, reason}`), returns the first value if it's `{:ok, _}`,
  otherwise calls the function with the error reason.

  For Option types (`nil` or any value), returns the first value if it's not `nil`,
  otherwise calls the function.

  This is the lazy version of `or_else/2` - the function is only called when needed.

  ## Examples

      iex> Err.or_else_lazy({:ok, "cache.db"}, fn _ -> {:ok, "disk.db"} end)
      {:ok, "cache.db"}

      iex> Err.or_else_lazy({:error, :cache_miss}, fn _reason -> {:ok, "disk.db"} end)
      {:ok, "disk.db"}

      iex> Err.or_else_lazy({:error, :timeout}, fn reason -> {:error, "Fallback failed: \#{reason}"} end)
      {:error, "Fallback failed: timeout"}

      iex> Err.or_else_lazy("primary", fn _ -> "backup" end)
      "primary"

      iex> Err.or_else_lazy(nil, fn _ -> "backup" end)
      "backup"

  """
  @spec or_else_lazy(value(), (any() -> any())) :: value()
  def or_else_lazy(value, fun)
  def or_else_lazy(nil, fun), do: fun.(nil)
  def or_else_lazy({:ok, _} = first, _fun), do: first
  def or_else_lazy({:error, reason}, fun), do: fun.(reason)
  def or_else_lazy(first, _fun), do: first

  def wrap(term, opts \\ [])

  def wrap(term, opts) when is_atom(term), do: struct(term, opts)
  def wrap(term, _), do: struct(Err.GenericError, term)

  @spec message(struct()) :: String.t()
  def message(%_{mod: mod, reason: reason}) when not is_nil(mod) do
    mod.format_error(reason)
  end

  def message(exception) do
    Exception.message(exception)
  end

  defp fallback_task_result(nil, task), do: Task.shutdown(task, :brutal_kill)
  defp fallback_task_result(reply, _task), do: reply

  defp normalize_task_reply({:ok, value}), do: normalize_result(value)
  defp normalize_task_reply({:exit, :timeout}), do: {:error, :timeout}
  defp normalize_task_reply({:exit, reason}), do: {:error, {:exit, reason}}
  defp normalize_task_reply(nil), do: {:error, :timeout}

  defp normalize_result({:ok, _} = ok), do: ok
  defp normalize_result({:error, _} = error), do: error

  defp normalize_result(tuple) when is_tuple(tuple) do
    case elem(tuple, 0) do
      :ok -> tuple
      :error -> tuple
      _ -> {:ok, tuple}
    end
  end

  defp normalize_result(other), do: {:ok, other}

  defp result_payload({_, value}), do: value
  defp result_payload(tuple), do: tuple |> Tuple.delete_at(0) |> Tuple.to_list()
end
