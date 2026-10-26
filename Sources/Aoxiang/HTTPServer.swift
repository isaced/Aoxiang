//
//  HTTPServer.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/29.
//

import Foundation

#if os(iOS)
import UIKit
#endif

public typealias MiddlewareNext = () async -> Void
public typealias Middleware = (HTTPRequest, HTTPResponse, @escaping MiddlewareNext) async -> Void

/// Middleware class
///
/// You can create a middleware by subclassing `HTTPMiddleware` or just using a closure.
/// If you want to subclass `HTTPMiddleware`, you should override `handle` method.
/// If you want to use a closure, you can just pass it to `HTTPMiddleware` initializer.
///
///     let server = HTTPServer()
///     server.use { req, res, next in
///          print("Middleware 1")
///          await next()
///     }
///     server.start(3000)
///
open class HTTPMiddleware {
    var handler: Middleware?

    init(_ handler: Middleware? = nil) {
        self.handler = handler
    }

    public func handle(_ req: HTTPRequest, _ res: HTTPResponse, next: @escaping MiddlewareNext) async {
        await next()
    }
}

/// The HTTP server class
///
/// You can create a server instance by `HTTPServer()`.
///
///     let server = HTTPServer()
///     server.get("/") { req, res in
///          res.send("Hello World")
///     }
///     try server.start(3000)
open class HTTPServer {
    /// A butil-in router middleware
    let router = HTTPRouter()

    /// A middleware stack
    var middleware: [HTTPMiddleware] = []

    /// Automatically suspend in background, default is true
    ///
    /// If you set it to false, you should handle background task by yourself.
    /// If you set it to true, the server will suspend automatically when app enter background,
    /// And resume when app enter foreground.
    /// You can change this property at any time, even when server is running.
    ///
    /// Note: This property only works on iOS.
    public var automaticallySuspendInBackground = true

    /// Maximum accepted request body size in bytes, default is 10 MiB.
    ///
    /// Requests declaring a larger `Content-Length` are rejected with
    /// `413 Content Too Large` before the body is read.
    public var maxRequestBodySize = 10 * 1024 * 1024

    private var port: in_port_t = 8080

    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier?
    #endif

    /// Create a server instance
    public init() {}

    /// Add a middleware to the server, by a `HTTPMiddleware` instance.
    public func use(_ middleware: HTTPMiddleware) {
        self.middleware.append(middleware)
    }

    /// Add a middleware to the server, by a closure.
    public func use(_ middleware: @escaping Middleware) {
        let mid = HTTPMiddleware { req, res, next async in
            await middleware(req, res, next)
        }
        self.middleware.append(mid)
    }

    /// Socket instance
    private var socket: Socket?

    /// Socket set
    private var sockets = Set<Socket>()

    /// Queue for socket set
    private let queue = DispatchQueue(label: "aoxiang.socket")

    /// Start server on a port, default is 8080.
    ///
    /// - Parameter port: port number
    /// - Throws: Socket error
    /// - Returns: Void
    public func start(_ port: in_port_t = 8080) throws {
        self.port = port

        // load router middleware, once per server instance
        if !self.middleware.contains(where: { $0 === self.router }) {
            self.use(self.router)
        }

        // start server
        self.stop()
        let listeningSocket = try Socket(port: port)
        self.socket = listeningSocket
        Task(priority: .background) { [weak self, listeningSocket] in
            while let clientSocket: Socket = try? listeningSocket.accept() {
                Task(priority: .background) { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.queue.async {
                        strongSelf.sockets.insert(clientSocket)
                    }

                    await strongSelf.handleConnection(clientSocket)

                    strongSelf.queue.async {
                        strongSelf.sockets.remove(clientSocket)
                    }
                }
            }

            // The accept loop exits when its listening socket is closed. Only
            // stop the server if this loop still owns the active socket: a
            // restart may have already installed a new listener.
            guard let strongSelf = self else { return }
            if strongSelf.socket === listeningSocket {
                strongSelf.stop()
            }
        }

        /// Setup background task
        #if os(iOS)
        if self.automaticallySuspendInBackground {
            self.setupAutoSuspendInBackground()
        }
        #endif
    }

    #if os(iOS)

    /// Setup Auto suspend in background (iOS only)
    private func setupAutoSuspendInBackground() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf._stop()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let strongSelf = self else { return }
            try? strongSelf.start(strongSelf.port)
        }
    }

    /// Remove Auto suspend in background when server is stopped (iOS only)
    private func removeAutoSuspendInBackground() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func startbackgroundTask() {
        if self.backgroundTask == .invalid {
            print("[Aoxiang] Did start background task")
            self.backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                print("[Aoxiang] Application is being suspended while HTTPServer is still connected")
                self.endBackgroundTask()
            })
        }
    }

    private func endBackgroundTask() {
        if self.backgroundTask == .invalid {
            if self.automaticallySuspendInBackground, UIApplication.shared.applicationState == .background {
                print("[Aoxiang] Did end background task")
                self._stop()
            }
            UIApplication.shared.endBackgroundTask(.invalid)
            self.backgroundTask = .invalid
        }
    }
    #endif

    /// Stop server
    public func stop() {
        #if os(iOS)
        self.removeAutoSuspendInBackground()
        #endif

        self._stop()
    }

    /// Internal stop
    private func _stop() {
        for socket in self.sockets {
            socket.close()
        }
        self.queue.sync {
            self.sockets.removeAll(keepingCapacity: true)
        }
        self.socket?.close()
        self.socket = nil
    }

    /// Handle a connection
    private func handleConnection(_ socket: Socket) async {
        #if os(iOS)
        if await UIApplication.shared.applicationState == .background {
            self.startbackgroundTask()
        }
        #endif

        let parser = HTTPParser(maxRequestBodySize: self.maxRequestBodySize)
        while true {
            do {
                let request = try parser.readHttpRequest(socket)
                await self.dispatch(request, response: HTTPResponse(socket: socket))
                if socket.isClosed {
                    break
                }
            } catch SocketError.connectionClosed {
                break
            } catch let error as HttpParserError {
                self.sendErrorResponse(for: error, on: socket)
                break
            } catch {
                self.sendErrorResponse(statusCode: 400, on: socket)
                break
            }
        }
        socket.close()
    }

    private func sendErrorResponse(for error: HttpParserError, on socket: Socket) {
        let statusCode: Int
        switch error {
        case .bodyTooLarge:
            statusCode = 413
        case .headersTooLarge:
            statusCode = 431
        case .chunkedBodyNotSupported:
            statusCode = 501
        default:
            statusCode = 400
        }
        self.sendErrorResponse(statusCode: statusCode, on: socket)
    }

    private func sendErrorResponse(statusCode: Int, on socket: Socket) {
        let response = HTTPResponse(socket: socket)
        response.statusCode = statusCode
        response.send("\(statusCode) \(response.reasonPhrase)")
    }

    /// Dispatch a request
    private func dispatch(_ request: HTTPRequest, response: HTTPResponse) async {
        // Middleware
        var index = -1
        func next() async {
            index += 1
            if index < self.middleware.count {
                let middleware = self.middleware[index]
                if let handler = middleware.handler {
                    await handler(request, response, next)
                } else {
                    await middleware.handle(request, response, next: next)
                }
            }
        }
        await next()
    }
}

/// Shortcut for register a route
public extension HTTPServer {
    func get(_ path: String, handler: @escaping HTTPRouterHandler) {
        self.router.register("GET", path: path, handler: handler)
    }

    func post(_ path: String, handler: @escaping HTTPRouterHandler) {
        self.router.register("POST", path: path, handler: handler)
    }

    func put(_ path: String, handler: @escaping HTTPRouterHandler) {
        self.router.register("PUT", path: path, handler: handler)
    }

    func delete(_ path: String, handler: @escaping HTTPRouterHandler) {
        self.router.register("DELETE", path: path, handler: handler)
    }

    func patch(_ path: String, handler: @escaping HTTPRouterHandler) {
        self.router.register("PATCH", path: path, handler: handler)
    }

    func options(_ path: String, handler: @escaping HTTPRouterHandler) {
        self.router.register("OPTIONS", path: path, handler: handler)
    }

    func head(_ path: String, handler: @escaping HTTPRouterHandler) {
        self.router.register("HEAD", path: path, handler: handler)
    }

    func trace(_ path: String, handler: @escaping HTTPRouterHandler) {
        self.router.register("TRACE", path: path, handler: handler)
    }

    func connect(_ path: String, handler: @escaping HTTPRouterHandler) {
        self.router.register("CONNECT", path: path, handler: handler)
    }
}
