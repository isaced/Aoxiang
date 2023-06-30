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
    case recvFailed(String)
    case getPeerNameFailed(String)
    case getNameInfoFailed(String)
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

        // reuse socket address (for fix "Address already in use")
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &serveraddr, socklen_t(socklen))

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

    /// Read a single byte off the socket. This method is optimized for reading
    /// a single byte. For reading multiple bytes, use read(length:), which will
    /// pre-allocate heap space and read directly into it.
    ///
    /// - Returns: A single byte
    /// - Throws: SocketError.recvFailed if unable to read from the socket
    open func read() throws -> UInt8 {
        var byte: UInt8 = 0
        let count = Darwin.read(sock, &byte, 1)
        guard count > 0 else {
            throw SocketError.recvFailed(errorDescription())
        }
        return byte
    }

    /// Read up to `length` bytes from this socket
    ///
    /// - Parameter length: The maximum bytes to read
    /// - Returns: A buffer containing the bytes read
    /// - Throws: SocketError.recvFailed if unable to read bytes from the socket
    open func read(length: Int) throws -> [UInt8] {
        return try [UInt8](unsafeUninitializedCapacity: length) { buffer, bytesRead in
            bytesRead = try read(into: &buffer, length: length)
        }
    }

    static let kBufferLength = 1024

    /// Read up to `length` bytes from this socket into an existing buffer
    ///
    /// - Parameter into: The buffer to read into (must be at least length bytes in size)
    /// - Parameter length: The maximum bytes to read
    /// - Returns: The number of bytes read
    /// - Throws: SocketError.recvFailed if unable to read bytes from the socket
    func read(into buffer: inout UnsafeMutableBufferPointer<UInt8>, length: Int) throws -> Int {
        var offset = 0
        guard let baseAddress = buffer.baseAddress else { return 0 }

        while offset < length {
            // Compute next read length in bytes. The bytes read is never more than kBufferLength at once.
            let readLength = offset + Socket.kBufferLength < length ? Socket.kBufferLength : length - offset
            let bytesRead = Darwin.read(sock, baseAddress + offset, readLength)
            guard bytesRead > 0 else {
                throw SocketError.recvFailed(errorDescription())
            }
            offset += bytesRead
        }

        return offset
    }

    private static let CR: UInt8 = 13
    private static let NL: UInt8 = 10

    public func readLine() throws -> String {
        var characters = ""
        var index: UInt8 = 0
        repeat {
            index = try read()
            if index > Socket.CR { characters.append(Character(UnicodeScalar(index))) }
        } while index != Socket.NL
        return characters
    }

    public func peername() throws -> String {
        var addr = sockaddr(), len = socklen_t(MemoryLayout<sockaddr>.size)
        if getpeername(sock, &addr, &len) != 0 {
            throw SocketError.getPeerNameFailed(errorDescription())
        }
        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(&addr, len, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) != 0 {
            throw SocketError.getNameInfoFailed(errorDescription())
        }
        return String(cString: hostBuffer)
    }

    /// A utility function to get a human-readable description of the last error.
    func errorDescription() -> String {
        return String(cString: strerror(errno))
    }
}
