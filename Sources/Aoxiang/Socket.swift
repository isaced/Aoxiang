//
//  Socket.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/29.
//

import Foundation

/// Errors thrown by Socket.
enum SocketError: Error {
    case bindFailed(String)
    case listenFailed(String)
    case writeFailed(String)
    case acceptFailed(String)
}

/// A wrapper around the POSIX socket API.
class Socket: Hashable, Equatable {
    let sock: Int32

    init(sock: Int32) {
        self.sock = sock
    }

    init(port: in_port_t) throws {
        let zero = Int8(0)
        let transportLayerType = SOCK_STREAM // TCP
        let internetLayerProtocol = AF_INET // IPv4
        let socklen = UInt8(socklen_t(MemoryLayout<sockaddr_in>.size))
        var serveraddr = sockaddr_in()
        serveraddr.sin_family = sa_family_t(internetLayerProtocol)
        serveraddr.sin_port = port.bigEndian
        serveraddr.sin_addr = in_addr(s_addr: in_addr_t(0))
        serveraddr.sin_zero = (zero, zero, zero, zero, zero, zero, zero, zero)
        self.sock = socket(internetLayerProtocol, Int32(transportLayerType), 0)

        // bind
        let bindResult = withUnsafePointer(to: &serveraddr) {
            bind(sock, UnsafePointer<sockaddr>(OpaquePointer($0)), socklen_t(socklen))
        }
        if bindResult == -1 {
            throw SocketError.bindFailed(errorDescription())
        }

        // listen
        if listen(sock, SOMAXCONN) == -1 {
            throw SocketError.listenFailed(errorDescription())
        }

        print("Server listening on port \(port)")
    }

    static func == (lhs: Socket, rhs: Socket) -> Bool {
        return lhs.sock == rhs.sock
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(sock)
    }

    public func accept() throws -> Socket {
        let clientSocket = Darwin.accept(sock, nil, nil)
        if clientSocket == -1 {
            throw SocketError.acceptFailed(errorDescription())
        }
        return Socket(sock: clientSocket)
    }

    public func close() {
        Darwin.close(sock)
    }

    public func write(_ string: String) throws {
        try writeUInt8(ArraySlice(string.utf8))
    }

    private func writeUInt8(_ data: ArraySlice<UInt8>) throws {
        try data.withUnsafeBufferPointer {
            try writeBuffer($0.baseAddress!, length: data.count)
        }
    }

    private func writeBuffer(_ pointer: UnsafeRawPointer, length: Int) throws {
        var sent = 0
        while sent < length {
            let result = Darwin.write(sock, pointer + sent, Int(length - sent))
            if result <= 0 {
                throw SocketError.writeFailed(errorDescription())
            }
            sent += result
        }
    }

    /// A utility function to get a human-readable description of the last error.
    func errorDescription() -> String {
        return String(cString: strerror(errno))
    }
}
