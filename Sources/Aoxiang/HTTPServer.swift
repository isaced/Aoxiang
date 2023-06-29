//
//  HTTPServer.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/29.
//

import Foundation

open class HTTPServer {
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

    private func handleConnection(_ socket: Socket) {
        let html = "hello"
        let httpResponse = """
        HTTP/1.1 200 OK
        server: Aoxiang
        content-length: \(html.count)

        \(html)
        """
        do {
            try socket.write(httpResponse)
        } catch {
            print("Failed to send response: \(error)")
        }
        socket.close()
    }
}
