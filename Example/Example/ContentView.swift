//
//  ContentView.swift
//  Example
//
//  Created by isaced on 2023/7/3.
//

import Aoxiang
import Combine
import SwiftUI

struct ContentView: View {
    var server = HTTPServer()

    @State var isRuning = false
    var body: some View {
        VStack {
            Toggle(isOn: $isRuning) {
                Text(isRuning ? "Stop" : "Start")
            }
            .labelsHidden()
            .onReceive(Just(isRuning)) { _ in
                toggleServer()
            }
        }
        .padding()
        .onAppear {
            initRouter()
        }
    }

    func initRouter() {
        server.get("/") { _, res in
            res.send("Hello!")
        }
        server.automaticallySuspendInBackground = false
        toggleServer()
    }

    func toggleServer() {
        do {
            if isRuning {
                print("Start server")
                try server.start(3000)
            } else {
                print("Stop server")
                server.stop()
            }
        } catch {
            print("Start error: \(error)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
