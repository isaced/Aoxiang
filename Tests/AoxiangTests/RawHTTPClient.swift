import Darwin
import Foundation

struct RawHTTPResponse {
    let statusLine: String
    let headers: [(name: String, value: String)]
    let body: Data
    let raw: Data
}

enum RawHTTPClientError: Error {
    case socket(String)
}

enum RawHTTPClient {
    static func get(_ path: String, port: UInt16, headers: [String: String] = [:]) throws -> RawHTTPResponse {
        var request = "GET \(path) HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n"
        for (name, value) in headers {
            request += "\(name): \(value)\r\n"
        }
        request += "\r\n"
        return try send(Data(request.utf8), port: port)
    }

    static func send(_ request: Data, port: UInt16) throws -> RawHTTPResponse {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw RawHTTPClientError.socket(errorDescription())
        }
        defer { Darwin.close(fd) }

        var timeout = timeval(tv_sec: 10, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let connectResult = withUnsafePointer(to: &addr) {
            Darwin.connect(fd, UnsafePointer<sockaddr>(OpaquePointer($0)), socklen_t(MemoryLayout<sockaddr_in>.size))
        }
        guard connectResult == 0 else {
            throw RawHTTPClientError.socket(errorDescription())
        }

        try request.withUnsafeBytes { buffer in
            var sent = 0
            while sent < buffer.count {
                let written = Darwin.write(fd, buffer.baseAddress! + sent, buffer.count - sent)
                guard written > 0 else {
                    throw RawHTTPClientError.socket(errorDescription())
                }
                sent += written
            }
        }

        var raw = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            let received = chunk.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
            if received <= 0 { break }
            raw.append(contentsOf: chunk[0 ..< received])
        }

        return parse(raw)
    }

    private static func parse(_ raw: Data) -> RawHTTPResponse {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerEnd = raw.range(of: separator) else {
            return RawHTTPResponse(statusLine: "", headers: [], body: raw, raw: raw)
        }

        let headerBlock = String(decoding: raw[..<headerEnd.lowerBound], as: UTF8.self)
        var lines = headerBlock.components(separatedBy: "\r\n")
        let statusLine = lines.first ?? ""
        lines.removeFirst()

        let headers = lines.compactMap { line -> (name: String, value: String)? in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let name = String(line[..<colon])
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            return (name, value)
        }

        let body = raw[headerEnd.upperBound...]
        return RawHTTPResponse(statusLine: statusLine, headers: headers, body: Data(body), raw: raw)
    }

    private static func errorDescription() -> String {
        String(cString: strerror(errno))
    }
}
