//
//  File.swift
//
//
//  Created by isaced on 2023/7/2.
//

import Foundation

func fetch(_ path: String, method: String = "GET", body: String? = nil) async -> String {
    let url = URL(string: "http://localhost:8080" + path)!
    var request = URLRequest(url: url)
    request.httpMethod = method
    if let body {
        request.httpBody = body.data(using: .utf8)
    }
    let (data, _) = try! await URLSession.shared.data(for: request)
    return String(data: data, encoding: .utf8)!
}
