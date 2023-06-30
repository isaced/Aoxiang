//
//  HTTPServer.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/29.
//

import Foundation

open class HTTPServer {
    let router = HTTPRouter()

    var socket: Socket?
    private var sockets = Set<Socket>()
    private let queue = DispatchQueue(label: "aoxiang.socket")
    public func start(_ port: in_port_t = 8080) throws {
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

    private func dispatch(_ request: HTTPRequest) -> ([String: String], (HTTPRequest, HTTPResponse) -> Void) {
        if let result = router.route(request.method, path: request.path) {
            return result
        }

        return ([:], { _, response in
            response.statusCode = 404
            response.reasonPhrase = "Not Found"
            response.content = "Not Found"
        })
    }

    private func handleConnection(_ socket: Socket) {
        let parser = HTTPParser()
        while let request = try? parser.readHttpRequest(socket) {
            let request = request
            request.address = try? socket.peername()
            let (params, handler) = self.dispatch(request)
            request.params = params
            let response = HTTPResponse(socket: socket)
            handler(request, response)
        }
        socket.close()
    }
}
