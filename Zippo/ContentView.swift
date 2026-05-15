//
//  ContentView.swift
//  Zippo
//
//  Created by paal on 15/05/2026.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: ZippoDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(ZippoDocument()))
}
