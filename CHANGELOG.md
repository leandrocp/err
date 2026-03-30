# Changelog

## [0.2.3](https://github.com/leandrocp/err/compare/v0.2.2...v0.2.3) (2026-03-30)


### Features

* add flow normalization helpers ([4d3eec7](https://github.com/leandrocp/err/commit/4d3eec7f41e5ca75754c1c014b692b1b127953de))
* add predicate and composition helpers ([#13](https://github.com/leandrocp/err/issues/13)) ([9268b16](https://github.com/leandrocp/err/commit/9268b165891521d8a9b605bd72011898efaec11c))
* add task result helpers ([a9f22b5](https://github.com/leandrocp/err/commit/a9f22b5cf7ee79454b3e5a11672d56b5e60f2283))

## 0.2.2 - 2025-12-15

### Changed
- Fix `wrap/2` dialyzer errors

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
