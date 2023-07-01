//
//  HTTPRouter.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/30.
//

import Foundation

public typealias HTTPRouterHandler = (HTTPRequest, HTTPResponse) -> Void

class HTTPRouter: HTTPMiddleware {
    private var routes: [String: [String: HTTPRouterHandler]] = [:]

    public func register(_ method: String, path: String, handler: @escaping HTTPRouterHandler) {
        if routes[method] == nil {
            routes[method] = [:]
        }
        routes[method]?[extractPath(path)] = handler
    }

    private func route(_ method: String, path: String) -> (HTTPRouterHandler)? {
        if let handler = routes[method]?[path] {
            return handler
        }
        return nil
    }

    /// handle request
    override func handle(_ req: HTTPRequest, _ res: HTTPResponse, next: @escaping () -> Void) {
        if let handler = route(req.method, path: req.path) {
            handler(req, res)
        } else {
            res.statusCode = 404
            res.send("404 Not Found")
        }
        next()
    }

    func extractPath(_ path: String) -> String {
        let components = path.components(separatedBy: "?")
        return components[0]
    }
}
