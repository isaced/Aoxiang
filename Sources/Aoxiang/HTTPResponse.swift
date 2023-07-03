//
//  HTTPResponse.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/30.
//

import Foundation

/// HTTP response
///
/// This class is used to store a HTTP response.
/// - You can send a response by calling `send` method.
/// - You can also send a chunked response by calling `write` method, and call `end` method to end the response.
/// - You can also send a SSE response by calling `sendEventSource` method.
public class HTTPResponse {
    public var statusCode: Int = 200
    public var reasonPhrase: String = "OK"
    public var headers = ["Server": "Aoxiang"]
    var content = ""
    var length: Int { content.count }

    private var eventSource: EventSource?
    private var headerSent = false
    private var isChunked: Bool {
        headers.contains(where: { $0.key.lowercased() == "transfer-encoding" && $0.value.lowercased() == "chunked" })
    }

    private var socket: Socket

    /// Initialize a HTTP response with a socket.
    init(socket: Socket) {
        self.socket = socket
    }

    /// Update and send HTTP Header to client.
    /// 
    /// - Parameters:
    ///    - additionalHeaders: additional headers to be sent
    /// 
    /// Note: This method will not close the connection,
    ///       If you want to close the connection, call `end` method.
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

    /// Send string content to client.
    ///
    /// - Parameters:
    ///     - content: content to be sent
    ///
    /// Note: This method will not close the connection,
    ///       If you want to close the connection, call `end` method.
    public func write(_ content: String) {
        writeHeader(["Transfer-Encoding": "chunked"])

        let hexLength = String(content.count, radix: 16)
        try? socket.write(hexLength.description + "\r\n" + content + "\r\n")
    }

    /// Send string content to client, and close the connection.
    public func send(_ content: String) {
        self.content = content
        writeHeader()

        try? socket.write(content)
        socket.close()
    }

    /// Send close event to client, and close the connection.
    public func end() {
        if isChunked {
            try? socket.write("0\r\n\r\n")
        }
        socket.close()
    }
}

/// SSE response
public extension HTTPResponse {
    /// EventSource for SSE(Server-Sent Events)
    ///
    /// This class is used to send SSE events to client.
    /// You can send a event by calling `dispatchMessage` method.
    /// don't forget to call `close` method when you want to close the connection.
    class EventSource {
        private var socket: Socket
        private var isClosed = false

        init(socket: Socket) {
            self.socket = socket
        }

        /// Dispatch a message to client
        ///
        /// - Parameters:
        ///  - message: message to be sent
        ///  - event: event name, optional, default is nil
        public func dispatchMessage(_ message: String, event: String? = nil) {
            guard !isClosed else { return }
            if let event {
                try? socket.write("event: \(event)\r\n")
            }
            try? socket.write("data: \(message)\r\n\r\n")
        }

        public func close() {
            isClosed = true
            try? socket.write("data: \r\n\r\n")
            socket.close()
        }
    }

    /// Prepare SSE(Server-Sent Events) response
    ///
    /// This method is used to prepare SSE response.
    /// You can send SSE events to client by calling `dispatchMessage` method of the returned `EventSource` object.
    /// don't forget to call `close` method of the returned `EventSource` object when you want to close the connection.
    /// - Returns: EventSource
    func sendEvents() -> EventSource {
        writeHeader([
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        ])

        eventSource = EventSource(socket: socket)
        return eventSource!
    }
}
