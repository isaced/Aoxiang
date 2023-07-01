//
//  HTTPRequest.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/30.
//

import Foundation

public struct HTTPRequestBody {
    public var bytes: [UInt8]? = nil

    public func toString() -> String? {
        if let bytes {
            return String(bytes: bytes, encoding: .utf8)
        }
        return nil
    }
}

public class HTTPRequest {
    public var path: String = ""
    public var query: [(String, String)] = []
    public var method: String = ""
    public var headers: [String: String] = [:]
    public var body: HTTPRequestBody?
    public var address: String? = ""
    public var params: [String: String] = [:]

    func loadBody(bytes: [UInt8]) {
        body = HTTPRequestBody(bytes: bytes)
    }
}
