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

    private var customReasonPhrase: String?

    /// Reason phrase for the status line.
    ///
    /// Defaults to the standard phrase for `statusCode` unless explicitly set.
    public var reasonPhrase: String {
        get { customReasonPhrase ?? Self.defaultReasonPhrase(for: statusCode) }
        set { customReasonPhrase = newValue }
    }

    public var headers = ["Server": "Aoxiang"]

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

        let hexLength = String(content.utf8.count, radix: 16)
        try? socket.write(hexLength.description + "\r\n" + content + "\r\n")
    }

    /// Send string content to client, and close the connection.
    public func send(_ content: String) {
        self.send(Data(content.utf8), contentType: "text/plain; charset=utf-8")
    }

    /// Send raw data to client, and close the connection.
    public func send(_ data: Data, contentType: String = "application/octet-stream") {
        if self.headers["Content-Type"] == nil {
            self.headers["Content-Type"] = contentType
        }
        self.headers["Content-Length"] = String(data.count)
        writeHeader()

        try? socket.write(data)
        socket.close()
    }

    /// Encode `value` as JSON, send it to client, and close the connection.
    public func sendJSON<T: Encodable>(_ value: T) {
        do {
            let data = try JSONEncoder().encode(value)
            self.send(data, contentType: "application/json")
        } catch {
            self.statusCode = 500
            self.send("500 \(self.reasonPhrase)")
        }
    }

    /// Send close event to client, and close the connection.
    public func end() {
        if isChunked {
            try? socket.write("0\r\n\r\n")
        }
        socket.close()
    }

    private static func defaultReasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 100: return "Continue"
        case 101: return "Switching Protocols"
        case 200: return "OK"
        case 201: return "Created"
        case 202: return "Accepted"
        case 203: return "Non-Authoritative Information"
        case 204: return "No Content"
        case 205: return "Reset Content"
        case 206: return "Partial Content"
        case 300: return "Multiple Choices"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 303: return "See Other"
        case 304: return "Not Modified"
        case 307: return "Temporary Redirect"
        case 308: return "Permanent Redirect"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 402: return "Payment Required"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 406: return "Not Acceptable"
        case 408: return "Request Timeout"
        case 409: return "Conflict"
        case 410: return "Gone"
        case 411: return "Length Required"
        case 412: return "Precondition Failed"
        case 413: return "Content Too Large"
        case 414: return "URI Too Long"
        case 415: return "Unsupported Media Type"
        case 416: return "Range Not Satisfiable"
        case 417: return "Expectation Failed"
        case 418: return "I'm a Teapot"
        case 421: return "Misdirected Request"
        case 422: return "Unprocessable Content"
        case 426: return "Upgrade Required"
        case 428: return "Precondition Required"
        case 429: return "Too Many Requests"
        case 431: return "Request Header Fields Too Large"
        case 500: return "Internal Server Error"
        case 501: return "Not Implemented"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
        case 505: return "HTTP Version Not Supported"
        default: return ""
        }
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
