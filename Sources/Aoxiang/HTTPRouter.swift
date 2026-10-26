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
    private struct PatternRoute {
        let segments: [String]
        let handler: HTTPRouterHandler

        func match(_ path: String) -> [String: String]? {
            let pathSegments = path.components(separatedBy: "/")
            guard pathSegments.count == self.segments.count else { return nil }

            var params: [String: String] = [:]
            for (patternSegment, pathSegment) in zip(self.segments, pathSegments) {
                if patternSegment.hasPrefix(":") {
                    let name = String(patternSegment.dropFirst())
                    guard !name.isEmpty, !pathSegment.isEmpty else { return nil }
                    params[name] = pathSegment
                } else if patternSegment != pathSegment {
                    return nil
                }
            }
            return params
        }
    }

    private var routes: [String: [String: HTTPRouterHandler]] = [:]
    private var patternRoutes: [String: [PatternRoute]] = [:]

    /// Register a handler to the router
    /// 
    /// - Parameters:
    ///  - method: The HTTP method, such as `GET`, `POST`, `PUT`, `DELETE`, etc.
    ///  - path: The path to match, such as `/users` or `/users/:id`.
    ///  - handler: The handler to handle the request.
    public func register(_ method: String, path: String, handler: @escaping HTTPRouterHandler) {
        let path = extractPath(path)
        if path.contains(":") {
            patternRoutes[method, default: []].append(PatternRoute(segments: path.components(separatedBy: "/"), handler: handler))
        } else {
            if routes[method] == nil {
                routes[method] = [:]
            }
            routes[method]?[path] = handler
        }
    }

    private func route(_ request: HTTPRequest) -> HTTPRouterHandler? {
        if let handler = routes[request.method]?[request.path] {
            return handler
        }
        for patternRoute in patternRoutes[request.method] ?? [] {
            if let params = patternRoute.match(request.path) {
                request.params = params
                return patternRoute.handler
            }
        }
        return nil
    }

    override func handle(_ req: HTTPRequest, _ res: HTTPResponse, next: @escaping MiddlewareNext) async {
        if let handler = route(req) {
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
