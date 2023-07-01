# Aoxiang
Aoxiang(翱翔) is a lightweight HTTP server library written in Swift for iOS/macOS/tvOS.

## Features

- Lightweight, Zero-dependency
- Asynchronous, Non-blocking
- Support HTTP/1.1
- Support HTTP chunked transfer encoding (streaming)
- Support SSE (Server-Sent Events)
- Middleware support
- Friendly API, keep it simple and easy to use

## Hello World

```swift
import Aoxiang

let server = HTTPServer()

server.get("/") { req, res in
    res.send("Hello World!")
}

try server.start(8080)
```

Then open your browser and visit `http://localhost:8080/` to see the result.

## Basic routing

Routing refers to how an application’s endpoints (URIs) respond to client requests. You define routing using methods of the `HTTPServer` instance that correspond to HTTP methods; for example, `get()` to handle GET requests and `post()` to handle POST requests.

The following examples illustrate defining simple routes.

Respond with `Hello World!` on the homepage:

```swift
server.get("/") { req, res in
    res.send("hello Aoxiang!")
}
```

Respond to POST request on the homepage:

```swift
server.post("/") { req, res in
    res.send("Got a POST request")
}
```

Respond to a PUT request to the `/user` route:

```swift
server.put("/user") { req, res in
    res.send("Got a PUT request at /user")
}
```

Respond to a DELETE request to the `/user` route:

```swift
server.delete("/user") { req, res in
    res.send("Got a DELETE request at /user")
}
```

## Async/Await

Aoixang supports `async`/`await` to handle asynchronous operations, it makes your code more readable and easier to maintain.

```swift
server.get("/async") { req, res async in
    let user = await readUserInfo()
    res.send(user.name)
}
```

## Middleware

Middleware functions are functions that have access to the HTTP request(`req`) and response(`res`) objects, and the next function in the application’s request-response cycle. The next function is a function in the router which, when invoked, executes the middleware succeeding the current middleware.

Middleware functions can perform the following tasks:

- Execute any code.
- Make changes to the request and the response objects.
- End the request-response cycle.
- Call the next middleware in the stack.

You can use middleware for many purposes in your web application, for example:

- Logging
- Authentication
- Error handling
- ...

Aoxiang supports middleware like [Express](https://expressjs.com/). You can use `use()` to add middleware to your server.

This example shows a middleware function with no mount path. The function is executed every time the app receives a request.

```swift
server.use { req, res, next in
    print("Time: \(Date())")
    next()
}
```

Also you can use `HTTPMiddleware` to implement middleware.

```swift
class TimeMiddleware: HTTPMiddleware {
    override func handle(_ req: HTTPRequest, _ res: HTTPResponse, next: @escaping () -> Void) {
        print("Time: \(Date())")
        next()
    }
}

server.use(TimeMiddleware())
```

> The order of middleware loading is important: middleware functions that are loaded first are also executed first.

## Chunked streaming

Aoxiang supports [HTTP chunked transfer encoding](https://en.wikipedia.org/wiki/Chunked_transfer_encoding) out of the box. You can use `write()` to send chunked data to client, and use `end()` to end the response.

```swift
server.get("/stream") { _, res in
    res.write("hi,")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        res.write("Aoxiang.")
        res.end()
    }
}
```

## SSE(Server-Sent Events)

Aoxiang supports [SSE(Server-Sent Events)](https://html.spec.whatwg.org/multipage/server-sent-events.html#server-sent-events) out of the box. You can use `sendEvents()` to get a `EventSource` and send events to client. don't forget to call `close()` to close the connection.

```swift
server.get("/sse") { req, res in
    let target = res.sendEvents()
    target.dispatchMessage("SSE Response:")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        target.dispatchMessage("chunk 1")
        target.close()
    }
}
```

## Change response header

Aoxiang provides a `headers` property to help you change response header, you can set it before call `send()` or `write()`.

This example shows how to set a single header:

```swift
server.post("/send") { req, res in
    res.headers["Access-Control-Allow-Origin"] = "*"
    // ...
}
```

This example shows how to set HTTP status code:

```swift
server.post("/send") { req, res in
    res.statusCode = 404
    // ...
}
```

> For more customization, you can check `HTTPResponse` class.

## Installation

### Swift Package Manager

- File > Swift Packages > Add Package Dependency
- Add `https://github.com/isaced/Aoxiang.git`
- Select "Up to Next Major" with "1.0.0"

or add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/isaced/Aoxiang.git", .upToNextMajor(from: "1.0.0"))
]
```

## FAQ

### Why named Aoxiang?

Aoxiang(翱翔) means "soar" in Chinese. I hope this library can help you to build your own web server lightweight and easily.

### res.send() vs res.write()

- `res.write()` is used to send chunked data to client, it will keep the connection alive, until you call `res.end()` manually.
- `res.send()` is used to send data to client, it will close the connection after sending data automatically.

## Contributing

You are welcome to contribute to this project. Fork and make a Pull Request, or create an Issue if you see any problem.

## License

Aoxiang is released under the MIT license. See LICENSE for details.