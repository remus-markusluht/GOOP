//
//  GOOPApp.swift
//  GOOP
//
//  Created by Remus-Markus Luht on 24.09.2026.
//

import SwiftUI

@main
struct GOOPApp: App {
    private let session = GOOPSession()

    var body: some Scene {
        WindowGroup {
            ContentView(session: session)
        }
    }
}
