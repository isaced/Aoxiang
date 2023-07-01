//
//  HTTPServer.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/29.
//

import Foundation

public typealias Middleware = (HTTPRequest, HTTPResponse, @escaping () -> Void) -> Void

open class HTTPMiddleware {
    var handler: Middleware?

    init(_ handler: Middleware? = nil) {
        self.handler = handler
    }

    public func handle(_ req: HTTPRequest, _ res: HTTPResponse, next: @escaping () -> Void) {
        next()
    }
}

open class HTTPServer {
    let router = HTTPRouter()

    var middleware: [HTTPMiddleware] = []

    public func use(_ middleware: HTTPMiddleware) {
        self.middleware.append(middleware)
    }

    public func use(_ middleware: @escaping Middleware) {
        let mid = HTTPMiddleware { req, res, next in
            middleware(req, res, next)
        }
        self.middleware.append(mid)
    }

    var socket: Socket?
    private var sockets = Set<Socket>()
    private let queue = DispatchQueue(label: "aoxiang.socket")
    public func start(_ port: in_port_t = 8080) throws {
        // load router middleware
        self.use(self.router)

        // start server
        self.stop()
        self.socket = try Socket(port: port)
        let priority = DispatchQoS.QoSClass.background
        DispatchQueue.global(qos: priority).async { [weak self] in
            guard let strongSelf = self else { return }
            while let socket: Socket = try? strongSelf.socket?.accept() {
                DispatchQueue.global(qos: priority).async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.queue.async {
                        strongSelf.sockets.insert(socket)
                    }

                    strongSelf.handleConnection(socket)

                    strongSelf.queue.async {
                        strongSelf.sockets.remove(socket)
                    }
                }
            }
            strongSelf.stop()
        }
    }

    public func stop() {
        for socket in self.sockets {
            socket.close()
        }
        self.queue.sync {
            self.sockets.removeAll(keepingCapacity: true)
        }
        self.socket?.close()
    }

    private func handleConnection(_ socket: Socket) {
        let parser = HTTPParser()
        while let request = try? parser.readHttpRequest(socket) {
            self.dispatch(request, response: HTTPResponse(socket: socket))
        }
        socket.close()
    }

    private func dispatch(_ request: HTTPRequest, response: HTTPResponse) {
        // Middleware
        var index = -1
        func next() {
            index += 1
            if index < self.middleware.count {
                let middleware = self.middleware[index]
                if let handler = middleware.handler {
                    handler(request, response, next)
                } else {
                    middleware.handle(request, response, next: next)
                }
            }
        }
        next()

        // Router
//        if let result = router.route(request.method, path: request.path) {
//            return result
//        }
    }
}
