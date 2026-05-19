//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Paal Øye-Strømme
//
//  TranslucentBackgroundEffect.swift
//  Rugzak
//
//  NSViewRepresentable that applies an NSVisualEffectView with behind-window
//  blending and makes the host NSWindow translucent.
//

import AppKit
import SwiftUI

struct TranslucentBackgroundEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> EffectView {
        EffectView(material: material, blendingMode: blendingMode)
    }

    func updateNSView(_ view: EffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }

    final class EffectView: NSVisualEffectView {
        init(material: NSVisualEffectView.Material, blendingMode: NSVisualEffectView.BlendingMode) {
            super.init(frame: .zero)
            self.material = material
            self.blendingMode = blendingMode
        }

        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isOpaque = false
            window?.backgroundColor = .clear
        }
    }
}
