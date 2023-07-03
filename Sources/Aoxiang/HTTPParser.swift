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
}

/// HTTP request parser
/// 
/// This class is used to parse a HTTP request from a socket.
class HTTPParser {
    public func readHttpRequest(_ socket: Socket) throws -> HTTPRequest {
        let statusLine = try socket.readLine()
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
        if let contentLength = request.headers["content-length"], let contentLengthValue = Int(contentLength) {
            // Prevent a buffer overflow and runtime error trying to create an `UnsafeMutableBufferPointer` with
            // a negative length
            guard contentLengthValue >= 0 else {
                throw HttpParserError.negativeContentLength
            }
            try request.loadBody(bytes: readBody(socket, size: contentLengthValue))
        }
        return request
    }

    private func readHeaders(_ socket: Socket) throws -> [String: String] {
        var headers = [String: String]()
        while case let headerLine = try socket.readLine(), !headerLine.isEmpty {
            let headerTokens = headerLine.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            if let name = headerTokens.first, let value = headerTokens.last {
                headers[name.lowercased()] = value.trimmingCharacters(in: .whitespaces)
            }
        }
        return headers
    }

    private func readBody(_ socket: Socket, size: Int) throws -> [UInt8] {
        return try socket.read(length: size)
    }
}
