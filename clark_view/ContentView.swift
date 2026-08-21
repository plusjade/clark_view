//
//  ContentView.swift
//  clark_view
//
//  Created by Jade Dominguez on 8/18/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let pixelWidth = Int((geometry.size.width * displayScale).rounded())
            let pixelHeight = Int((geometry.size.height * displayScale).rounded())

            AsyncImage(url: GameImageURL.url(pixelWidth: pixelWidth, pixelHeight: pixelHeight, day: "today")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "sportscourt")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

#Preview {
    ContentView()
}
