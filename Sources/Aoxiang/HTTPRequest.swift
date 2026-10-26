//
//  HTTPRequest.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/30.
//

import Foundation

/// HTTP request body
/// 
/// This struct is used to store the body of a HTTP request.
/// You can get the body as a string by calling `toString` method.
public struct HTTPRequestBody {
    public var bytes: [UInt8]? = nil

    public func toString() -> String? {
        if let bytes {
            return String(bytes: bytes, encoding: .utf8)
        }
        return nil
    }
}

/// HTTP request
/// 
/// This class is used to store a HTTP request.
public class HTTPRequest {
    public var path: String = ""
    public var query: [(String, String)] = []
    public var method: String = ""
    public var headers: [String: String] = [:]
    public var body: HTTPRequestBody?
    public var address: String? = ""
    public var params: [String: String] = [:]

    /// First query value for `name`, or `nil` when absent.
    public func queryValue(_ name: String) -> String? {
        self.query.first(where: { $0.0 == name })?.1
    }

    /// All query values for `name`, in request order.
    public func queryValues(_ name: String) -> [String] {
        self.query.filter { $0.0 == name }.map(\.1)
    }

    func loadBody(bytes: [UInt8]) {
        body = HTTPRequestBody(bytes: bytes)
    }
}
