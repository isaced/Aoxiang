//
//  HTTPParser.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/30.
//

import Foundation

enum HttpParserError: Error, Equatable {
    case invalidStatusLine(String)
    case negativeContentLength
    case invalidContentLength(String)
    case malformedHeader(String)
    case requestLineTooLong
    case headersTooLarge
    case bodyTooLarge
    case chunkedBodyNotSupported
}

/// HTTP request parser
///
/// This class is used to parse a HTTP request from a socket.
class HTTPParser {
    static let maxRequestLineBytes = 8 * 1024
    static let maxHeaderBytes = 32 * 1024
    static let maxHeaderCount = 100

    private let maxRequestBodySize: Int

    init(maxRequestBodySize: Int = 10 * 1024 * 1024) {
        self.maxRequestBodySize = maxRequestBodySize
    }

    public func readHttpRequest(_ socket: Socket) throws -> HTTPRequest {
        let statusLine: String
        do {
            statusLine = try socket.readLine(maxLength: Self.maxRequestLineBytes)
        } catch SocketError.lineTooLong {
            throw HttpParserError.requestLineTooLong
        }

        let statusLineTokens = statusLine.components(separatedBy: " ")
        if statusLineTokens.count < 3 {
            throw HttpParserError.invalidStatusLine(statusLine)
        }
        let request = HTTPRequest()
        request.address = try? socket.peername()
        request.method = statusLineTokens[0]
        let encodedPath = statusLineTokens[1].addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? statusLineTokens[1]
        let urlComponents = URLComponents(string: encodedPath)
        request.path = urlComponents?.path ?? ""
        request.query = urlComponents?.queryItems?.map { ($0.name, $0.value ?? "") } ?? []
        request.headers = try readHeaders(socket)

        if let transferEncoding = request.headers["transfer-encoding"],
           transferEncoding.lowercased().contains("chunked") {
            throw HttpParserError.chunkedBodyNotSupported
        }

        if let contentLength = request.headers["content-length"] {
            guard let contentLengthValue = Int(contentLength) else {
                throw HttpParserError.invalidContentLength(contentLength)
            }
            // Prevent a buffer overflow and runtime error trying to create an `UnsafeMutableBufferPointer` with
            // a negative length
            guard contentLengthValue >= 0 else {
                throw HttpParserError.negativeContentLength
            }
            guard contentLengthValue <= self.maxRequestBodySize else {
                throw HttpParserError.bodyTooLarge
            }
            try request.loadBody(bytes: readBody(socket, size: contentLengthValue))
        }
        return request
    }

    private func readHeaders(_ socket: Socket) throws -> [String: String] {
        var headers = [String: String]()
        var totalBytes = 0

        while true {
            let headerLine: String
            do {
                headerLine = try socket.readLine(maxLength: Self.maxHeaderBytes)
            } catch SocketError.lineTooLong {
                throw HttpParserError.headersTooLarge
            }

            if headerLine.isEmpty {
                break
            }

            totalBytes += headerLine.utf8.count + 2
            guard totalBytes <= Self.maxHeaderBytes, headers.count < Self.maxHeaderCount else {
                throw HttpParserError.headersTooLarge
            }

            guard let colon = headerLine.firstIndex(of: ":") else {
                throw HttpParserError.malformedHeader(headerLine)
            }
            let name = String(headerLine[..<colon]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else {
                throw HttpParserError.malformedHeader(headerLine)
            }
            let value = String(headerLine[headerLine.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            headers[name.lowercased()] = value
        }
        return headers
    }

    private func readBody(_ socket: Socket, size: Int) throws -> [UInt8] {
        return try socket.read(length: size)
    }
}
