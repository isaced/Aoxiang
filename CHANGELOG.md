# Changelog

All notable changes to Aoxiang are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-10-26

The first release since 1.0.0 (2023-07-01). It adds the request/response APIs that
the README already described as intended usage, and fixes a set of correctness and
lifecycle bugs — several of which made the server unreliable under restarts and load.

### Added

- iOS background support: `automaticallySuspendInBackground` stops the server when the app
  is backgrounded and restarts it in the foreground; a background task is held while a
  connection is served from the background.
- Example iOS app under `Example/`.
- Path parameters: `server.get("/users/:id")` with values on `req.params`; exact routes take
  precedence over parameterized ones (#31).
- Query helpers: `req.queryValue(_:)` and `req.queryValues(_:)`, duplicates preserved (#27).
- `res.send(_:contentType:)` for binary bodies and `res.sendJSON(_:)` for `Encodable` values (#28).
- SSE completion: `id:` field, `dispatchRetry(_:)`, and multiline `data:` encoding (#34).
- `HTTPServer.readTimeout` — opt-in per-connection socket read timeout (#26).
- `HTTPServer.maxRequestBodySize` — request body cap, default 10 MiB (#15).
- CI: macOS build + test job, plus iOS and tvOS cross-builds that also compile the test target
  so `#if os(iOS)` code is verified (#10, #17).

### Fixed

- The macOS build, broken by an unguarded `UIApplication` reference in the iOS background code (#1).
- `chunked` responses used `Character` counts instead of UTF-8 byte counts, corrupting any
  multi-byte payload (#14).
- The status line always said `OK`; the reason phrase is now derived from `statusCode` (#11).
- Malformed or oversized requests were dropped silently; they now return `400`, `413`, `431`,
  and `501` as appropriate (#15).
- `Transfer-Encoding: chunked` request bodies were ignored, so body bytes were parsed as a new
  request; they are now rejected explicitly (#15).
- Percent-encoded query values were double-encoded and never decoded (#27).
- Restarting a server could close the descriptor of the new listener (duplicate `close` on a
  recycled file descriptor) (#2).
- Writing to an already-closed socket could write into an unrelated connection that reused the
  descriptor; `Socket.write` now rejects closed sockets (#19).
- `_stop()` iterated the connection set outside its serial queue while other threads mutated it —
  undefined behavior that surfaced as random bind failures, hung requests, and an
  `unrecognized selector` crash (#30).
- The accept loop could remain blocked on a recycled descriptor and steal connections belonging to
  a newer listener; `stop()` now waits for the loop to exit (#33).
- Blocking `accept()` calls ran on the Swift concurrency cooperative pool and starved unrelated work
  on low-core machines; the accept loop now has its own thread (#16).
- The built-in router was re-registered on every `start()`, so handlers ran twice after a restart (#16).
- iOS background tasks never started (`nil` vs `.invalid` comparison), ended the wrong identifier,
  and leaked notification observers on every restart (#17).
- `HTTPMiddleware` could not actually be subclassed by library users: `handle` is now `open` and the
  initializer is `public` (#36).

### Changed

Behaviour changes worth knowing about when upgrading:

- `res.send(_:)` now sets `Content-Type: text/plain; charset=utf-8` when you have not set one, and
  always sends `Content-Length`. Responses are no longer close-delimited with a sniffed type.
- Requests outside the parser limits are rejected instead of silently ignored or misparsed.
- The reason phrase follows the status code unless you assign `res.reasonPhrase`.
- Accept runs on a dedicated thread per server; connections are still handled concurrently, and
  socket I/O remains blocking.

### Testing

- Test count grew from 8 to 42, including a POSIX raw HTTP client for asserting status lines,
  headers, and exact chunked/SSE framing.
- Lifecycle, parser-limit, timeout, response-body, path-parameter, SSE, and public-API (consumer-style,
  non-`@testable`) test suites added.
- The intermittent CI failure that hid the descriptor-reuse bug is fixed, and the suite is now stable
  across repeated runs.

### Documentation

- README rewritten: table of contents, full API reference for routing, requests, responses, streaming,
  middleware, configuration, status codes, threading model and limits, and explicit non-goals (#38, #20).

[1.1.0]: https://github.com/isaced/Aoxiang/releases/tag/1.1.0
