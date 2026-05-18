//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  Debug.swift
//  Rugzak
//
//  Utility enum for detecting the Xcode preview environment at runtime.
//

import Foundation

enum Debug {
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
