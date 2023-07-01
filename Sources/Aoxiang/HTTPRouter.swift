//
//  HTTPRouter.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/30.
//

import Foundation

class HTTPRouter: HTTPMiddleware {
    private var routes: [String: [String: (HTTPRequest, HTTPResponse) -> Void]] = [:]

    public func route(_ method: String, path: String) -> ((HTTPRequest, HTTPResponse) -> Void)? {
        if let handler = routes[method]?[path] {
            return handler
        }
        return nil
    }

    public func register(_ method: String, path: String, handler: @escaping (HTTPRequest, HTTPResponse) -> Void) {
        if routes[method] == nil {
            routes[method] = [:]
        }
        routes[method]?[path] = handler
    }

    override func handle(_ req: HTTPRequest, _ res: HTTPResponse, next: @escaping () -> Void) {
        if let handler = route(req.method, path: req.path) {
            handler(req, res)
            next()
        } else {
            next()
        }
    }
}
