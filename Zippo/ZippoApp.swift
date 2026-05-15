//
//  ZippoApp.swift
//  Zippo
//
//  Created by paal on 15/05/2026.
//

import SwiftUI

@main
struct ZippoApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ZippoDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
