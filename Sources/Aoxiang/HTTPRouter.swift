//
//  HTTPRouter.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/30.
//

import Foundation

class HTTPRouter {
    private var routes: [String: [String: (HTTPRequest, HTTPResponse) -> Void]] = [:]

    public func route(_ method: String, path: String) -> ([String: String], (HTTPRequest, HTTPResponse) -> Void)? {
        if let result = routes[method]?[path] {
            return ([:], result)
        }
        return nil
    }

    public func register(_ method: String, path: String, handler: @escaping (HTTPRequest, HTTPResponse) -> Void) {
        if routes[method] == nil {
            routes[method] = [:]
        }
        routes[method]?[path] = handler
    }
}
