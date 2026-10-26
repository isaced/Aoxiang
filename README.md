# Aoxiang

[![Swift](https://github.com/isaced/Aoxiang/actions/workflows/swift.yml/badge.svg)](https://github.com/isaced/Aoxiang/actions/workflows/swift.yml)

Aoxiang (翱翔) is a lightweight HTTP server library written in Swift for iOS / macOS / tvOS.

Zero dependency, async handlers, and an Express-style API. It is designed to embed a small HTTP server inside your app — a debug bridge, a local preview server, a LAN API — not to replace Vapor.

## Contents

- [Features](#features)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Routing](#routing)
- [Requests](#requests)
- [Responses](#responses)
- [Streaming and SSE](#streaming-and-sse)
- [Middleware](#middleware)
- [Configuration](#configuration)
- [iOS background behavior](#ios-background-behavior)
- [Threading model and limits](#threading-model-and-limits)
- [Status codes](#status-codes)
- [Non-goals](#non-goals)
- [FAQ](#faq)
- [Development](#development)

## Features

- Lightweight and zero-dependency
- `async`/`await` handler API with per-connection concurrency
- HTTP/1.1 routing (`get`, `post`, `put`, `delete`, `patch`, …) with path parameters
- Request parsing: method, path, query, headers, body, path parameters
- String / `Data` / JSON responses with automatic `Content-Length` and `Content-Type`
- HTTP chunked transfer encoding (streaming) and SSE (Server-Sent Events)
- Express-style middleware
- Request size limits and an opt-in read timeout
- Automatic background suspend/resume on iOS

## Installation

### Requirements

- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+
- Swift 5.5+

### Swift Package Manager

In Xcode: **File > Swift Packages > Add Package Dependency**, then add

```
https://github.com/isaced/Aoxiang.git
```

and select "Up to Next Major" with `1.0.0`, or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/isaced/Aoxiang.git", .upToNextMajor(from: "1.0.0"))
]
```

## Quick start

```swift
import Aoxiang

let server = HTTPServer()

server.get("/") { req, res in
    res.send("Hello World!")
}

try server.start(8080)
```

Open `http://localhost:8080/` in your browser. Call `server.stop()` to close the listener and any active connections.

`start(_:)` throws if the port cannot be bound, for example when it is already in use.

An iOS sample app lives in [`Example/`](Example).

### Async handlers

Route handlers are `async` closures, so you can await inside them:

```swift
server.get("/async") { req, res in
    let user = await readUserInfo()
    res.send(user.name)
}
```

## Routing

Register routes with the method that matches the HTTP verb:

```swift
server.get("/") { req, res in
    res.send("hello Aoxiang!")
}

server.post("/user") { req, res in
    res.send("Got a POST request at /user")
}

server.put("/user") { req, res in
    res.send("Got a PUT request at /user")
}

server.delete("/user") { req, res in
    res.send("Got a DELETE request at /user")
}
```

`patch`, `head`, `options`, `trace`, and `connect` are available as well.

### Path parameters

Single-segment parameters are supported, and are read from `req.params`:

```swift
server.get("/users/:id/posts/:postId") { req, res in
    res.send("user \(req.params["id"] ?? "") post \(req.params["postId"] ?? "")")
}
```

- Exact routes take precedence over parameterized routes.
- An empty segment does not match a parameter (`/users/` does not match `/users/:id`).
- Wildcards and optional segments are not supported.

A request that matches no route is answered with `404 Not Found`.

## Requests

`HTTPRequest` exposes the parsed request:

| Property | Description |
| --- | --- |
| `method` | HTTP method, e.g. `"GET"` |
| `path` | Percent-decoded path, query excluded |
| `query` | Query items as `[(String, String)]`, in request order |
| `queryValue(_:)` | First value for a key, `nil` when absent |
| `queryValues(_:)` | All values for a key, duplicates preserved |
| `params` | Path parameters for the matched route |
| `headers` | Lowercased header names |
| `body` | `HTTPRequestBody`: raw `bytes` and `toString()` |
| `address` | Peer address of the connection |

```swift
server.post("/echo") { req, res in
    let name = req.queryValue("name") ?? "anonymous"
    res.send("\(name): \(req.body?.toString() ?? "")")
}
```

Header names are lowercased, so read them as `req.headers["content-type"]`.

## Responses

```swift
// Text (Content-Type: text/plain; charset=utf-8)
res.send("Hello World!")

// Binary (Content-Type defaults to application/octet-stream)
res.send(pngData, contentType: "image/png")

// JSON via Encodable (Content-Type: application/json)
struct User: Codable { let id: Int; let name: String }
res.sendJSON(User(id: 1, name: "Aoxiang"))
```

`send` always sets an accurate `Content-Length` (in UTF-8 bytes) and closes the connection. A `Content-Type` you set yourself is kept.

Status and headers are set before the first `send`/`write`:

```swift
server.get("/created") { _, res in
    res.statusCode = 201
    res.headers["X-Trace-Id"] = "abc"
    res.send("created")
}
```

The reason phrase is derived from `statusCode` (`201 Created`, `404 Not Found`, …); assign `res.reasonPhrase` to override it.

Every route must respond — if a handler returns without calling `send`, `write`/`end`, or `sendEvents`, the client waits until the connection is closed.

## Streaming and SSE

### Chunked responses

`write()` sends a chunk and keeps the connection open; `end()` finishes the response and closes it.

```swift
server.get("/stream") { _, res in
    res.write("hi,")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        res.write("Aoxiang.")
        res.end()
    }
}
```

### Server-Sent Events

`sendEvents()` returns an `EventSource`. Call `close()` when you are done.

```swift
server.get("/sse") { _, res in
    let events = res.sendEvents()
    events.dispatchMessage("SSE Response:")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        events.dispatchMessage("chunk 1")
        events.close()
    }
}
```

Messages may span lines (one `data:` line per source line), and `event`/`id` are supported. `dispatchRetry(_:)` sends the reconnection interval hint:

```swift
events.dispatchMessage("line 1\nline 2", event: "update", id: "42")
events.dispatchRetry(3000)
```

## Middleware

Middleware has access to the request, the response, and `next`. It can run code, mutate the request/response, end the cycle, or pass control on — useful for logging, authentication, and similar cross-cutting work.

```swift
server.use { req, res, next in
    print("Time: \(Date())")
    await next()
}
```

Or subclass `HTTPMiddleware`:

```swift
class TimeMiddleware: HTTPMiddleware {
    override func handle(_ req: HTTPRequest, _ res: HTTPResponse, next: @escaping MiddlewareNext) async {
        print("Time: \(Date())")
        await next()
    }
}

server.use(TimeMiddleware())
```

> Order matters: middleware registered first runs first. Middleware registered before `start()` also runs before routing, so one that responds without calling `next()` short-circuits the router.

## Configuration

| Property | Default | Description |
| --- | --- | --- |
| `maxRequestBodySize` | 10 MiB | Bodies larger than this are rejected with `413` before being read |
| `readTimeout` | `0` (disabled) | Per-connection socket read timeout in seconds; stalled connections are closed |
| `automaticallySuspendInBackground` | `true` | iOS only, see below |

```swift
server.maxRequestBodySize = 512 * 1024
server.readTimeout = 30
```

## iOS background behavior

By default the server stops itself when the app enters the background and restarts on the same port when it returns to the foreground.

Set `automaticallySuspendInBackground = false` if you want to manage background lifetime yourself; Aoxiang then keeps the listener open and requests a background task when a connection is handled while the app is in the background.

## Threading model and limits

Aoxiang targets embedded/local servers — a debug API, a local preview, a LAN endpoint from an app.

- The accept loop runs on its own thread; each connection is handled concurrently, but socket reads and writes block. This is not an NIO-style non-blocking server.
- `send()` closes the connection, so keep-alive and pipelining are not supported. One request per connection.
- There is no write timeout and no connection cap; `readTimeout` limits how long a stalled read can hold a connection.
- Limits: request line 8 KiB, headers 32 KiB / 100 fields, body `maxRequestBodySize`.
- Chunked request bodies are not supported and are rejected with `501`; chunked responses are supported.

## Status codes

| Code | When |
| --- | --- |
| `400 Bad Request` | Malformed request line or header field |
| `404 Not Found` | No route matched |
| `413 Content Too Large` | `Content-Length` exceeds `maxRequestBodySize` |
| `431 Request Header Fields Too Large` | Header block exceeds the limits |
| `500 Internal Server Error` | `sendJSON` failed to encode |
| `501 Not Implemented` | Chunked request body |

Error responses are sent and then the connection is closed.

## Non-goals

- TLS, HTTP/2, WebSocket
- multipart/form-data parsing
- Linux support (the socket layer uses Darwin APIs)

## FAQ

### Why named Aoxiang?

Aoxiang (翱翔) means "soar" in Chinese. I hope this library can help you to build your own web server lightweight and easily.

### res.send() vs res.write()

- `res.send(...)` sends the complete response and closes the connection.
- `res.write(...)` sends one chunk and keeps the connection open until you call `res.end()`.

### Can I serve files?

There is no built-in static file handler yet. Read the file yourself and use `res.send(data, contentType:)`.

### Is the server reachable from other devices?

`start(_:)` binds `0.0.0.0`, so it is reachable on the local network. There is no TLS or authentication; keep it to trusted networks and local use.

## Development

```sh
swift build
swift test
```

CI runs the test suite on macOS and cross-compiles the package and tests for the iOS and tvOS simulators, since platform-gated code (`#if os(iOS)`) is not compiled by the macOS job.

## Contact

Follow and contact me on [Twitter](https://twitter.com/isacedx). If you find an issue, just [open a ticket](https://github.com/isaced/Aoxiang/issues/new). Pull requests are warmly welcome as well.

## License

Aoxiang is released under the MIT license. See LICENSE for details.
