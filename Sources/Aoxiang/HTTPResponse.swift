//
//  HTTPResponse.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/30.
//

import Foundation

class HTTPResponse {
    var statusCode: Int = 200
    var reasonPhrase: String = "OK"
    var content = ""
    var length: Int { content.count }
    var headers = ["Server": "Aoxiang"]
    private var headerSent = false
    private var isChunked: Bool {
        headers.contains(where: { $0.key.lowercased() == "transfer-encoding" && $0.value.lowercased() == "chunked" })
    }

    private var socket: Socket

    init(socket: Socket) {
        self.socket = socket
    }

    func writeHeader(_ additionalHeaders: [String: String] = [:]) {
        guard !headerSent else { return }
        headerSent = true

        headers.merge(additionalHeaders) { _, new in new }

        var responseHeader = String()

        responseHeader.append("HTTP/1.1 \(statusCode) \(reasonPhrase)\r\n")

        for (name, value) in headers {
            responseHeader.append("\(name): \(value)\r\n")
        }

        responseHeader.append("\r\n")

        try? socket.write(responseHeader)
    }

    func write(_ content: String) {
        writeHeader(["Transfer-Encoding": "chunked"])

        let hexLength = String(content.count, radix: 16)
        try? socket.write(hexLength.description + "\r\n")
        try? socket.write(content + "\r\n")
    }

    /// Send response to socket
    func send(_ content: String) {
        self.content = content
        writeHeader()

        try? socket.write(content)
        socket.close()
    }

    ///
    func end() {
        if isChunked {
            try? socket.write("0\r\n\r\n")
        }
        socket.close()
    }
}
