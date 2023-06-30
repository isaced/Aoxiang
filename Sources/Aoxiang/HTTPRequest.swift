//
//  HTTPRequest.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/30.
//

import Foundation

class HTTPRequest {
    public var path: String = ""
    public var queryParams: [(String, String)] = []
    public var method: String = ""
    public var headers: [String: String] = [:]
    public var body: [UInt8] = []
    public var address: String? = ""
    public var params: [String: String] = [:]
}
