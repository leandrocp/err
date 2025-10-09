# Changelog

## 0.2.1 - 2025-10-09

### Added
- Add usage-rules.md for LLMs

## 0.2.0 - 2025-10-09

### Added

- `usage-rules.md` file with comprehensive guidance for AI agents on using the library
- `ok/1` function to wrap values in `{:ok, value}` tuples
- `error/1` function to wrap values in `{:error, value}` tuples
- `unwrap_or/2` function to extract values with defaults
- `unwrap_or_lazy/2` function for lazy default computation
- `expect!/2` function for unwrapping `{:ok, value}` or raising a custom exception
- `expect_err!/2` function for unwrapping `{:error, reason}` or raising a custom exception
- `and_then/2` function for chaining operations on results
- `map/2` function for transforming success values
- `map_err/2` function for transforming error values
- `is_ok/1`, `is_err/1`, `is_some/1` guards for pattern matching
- `flatten/1` function for flattening nested results
- `all/1` function for combining lists of results (fail-fast)
- `values/1` function for extracting success values from lists
- `partition/1` function for splitting results into ok/error lists
- `replace/2` and `replace_lazy/2` for replacing success values
- `replace_err/2` and `replace_err_lazy/2` for replacing error values
- `or_else/2` and `or_else_lazy/2` for providing fallback values
- `wrap/1` and `wrap/2` for creating exception structs
- `message/1` for extracting exception messages
- Support for multi-element tuples (e.g., `{:ok, value, metadata}`)
- Result and Option type definitions
- Guards for use in pattern matching

## 0.1.0 - 2020-09-27

Initial release.
