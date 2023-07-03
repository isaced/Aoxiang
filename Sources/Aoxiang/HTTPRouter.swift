//
//  HTTPRouter.swift
//  Aoxiang
//
//  Created by isaced on 2023/6/30.
//

import Foundation

public typealias HTTPRouterHandler = (HTTPRequest, HTTPResponse) async -> Void

/// A Butil-in simple router middleware
/// 
/// This middleware is used to route requests to different handlers.
/// You can register a handler by calling `register` method.
/// 
class HTTPRouter: HTTPMiddleware {
    private var routes: [String: [String: HTTPRouterHandler]] = [:]

    /// Register a handler to the router
    /// 
    /// - Parameters:
    ///  - method: The HTTP method, such as `GET`, `POST`, `PUT`, `DELETE`, etc.
    ///  - path: The path to match, such as `/`, `/users`, `/users/:id`, etc.
    ///  - handler: The handler to handle the request.
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

    override func handle(_ req: HTTPRequest, _ res: HTTPResponse, next: @escaping MiddlewareNext) async {
        if let handler = route(req.method, path: req.path) {
            await handler(req, res)
        } else {
            res.statusCode = 404
            res.send("404 Not Found")
        }
        await next()
    }

    func extractPath(_ path: String) -> String {
        let components = path.components(separatedBy: "?")
        return components[0]
    }
}
