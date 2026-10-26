//
//  File.swift
//
//
//  Created by isaced on 2023/7/2.
//

import Foundation

func fetch(_ path: String, method: String = "GET", body: String? = nil, port: Int = 8080) async throws -> String {
    // Ephemeral sessions keep connections out of the shared pool: these tests start
    // and stop servers on the same port between cases, and a pooled connection to a
    // dead listener surfaces as a lost connection.
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 10
    let session = URLSession(configuration: configuration)
    defer { session.finishTasksAndInvalidate() }

    let url = URL(string: "http://127.0.0.1:\(port)" + path)!
    var request = URLRequest(url: url)
    request.httpMethod = method
    if let body {
        request.httpBody = body.data(using: .utf8)
    }
    let (data, _) = try await session.data(for: request)
    return String(decoding: data, as: UTF8.self)
}
