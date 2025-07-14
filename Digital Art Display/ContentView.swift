//
//  ContentView.swift
//  Digital Art Display
//
//  Created by Joao Fiadeiro on 7/14/25.
//

import SwiftUI

struct ArtworkItem: Identifiable {
    let id = UUID()
    let url: String
}

struct ContentView: View {
    @State private var selectedIndex = 0
    @State private var showGallery = false
    @FocusState private var focusedIndex: Int?
    
    let artworks = [
        ArtworkItem(url: "https://artblocks-mainnet.s3.amazonaws.com/3333.png"),
        ArtworkItem(url: "https://lvbgoishhi7kgdplrx5q4iolo533g7zfcy6zyqekzmigcmvtek3a.arweave.net/XUJnIkc6PqMN6437DiHLd3ezfyUWPZxAissQYTKzIrY"),
        ArtworkItem(url: "https://arweave.net/3TOEbf6HOgCKRd_Q1LggrQZ8ZLLudHZU1L8q6NnTVwg"),
        ArtworkItem(url: "https://arweave.net/4Q6Cfb01nyM3p2SEaobuuVXkloP_QbjjRY4zsziuDws")
    ]
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if !artworks.isEmpty {
                AsyncImage(url: URL(string: artworks[selectedIndex].url)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(2)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .animation(.easeInOut(duration: 0.3), value: selectedIndex)
                    case .failure(_):
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 100))
                            .foregroundColor(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
                .ignoresSafeArea()
            }
            
            VStack {
                Spacer()
                
                if showGallery {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 30) {
                            ForEach(artworks.indices, id: \.self) { index in
                                GalleryThumbnail(
                                    artwork: artworks[index],
                                    isSelected: index == selectedIndex,
                                    isFocused: focusedIndex == index,
                                    index: index
                                )
                                .focusable()
                                .focused($focusedIndex, equals: index)
                                .onTapGesture {
                                    selectedIndex = index
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showGallery = false
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 80)
                        .padding(.vertical, 40)
                    }
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0),
                                Color.black.opacity(0.9)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showGallery)
        }
        .onPlayPauseCommand {
            withAnimation {
                showGallery.toggle()
                if showGallery {
                    focusedIndex = selectedIndex
                }
            }
        }
        .onExitCommand {
            if showGallery {
                withAnimation {
                    showGallery = false
                }
            }
        }
    }
}

struct GalleryThumbnail: View {
    let artwork: ArtworkItem
    let isSelected: Bool
    let isFocused: Bool
    let index: Int
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(isSelected ? 0.3 : 0.1))
                .frame(width: 300, height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isFocused ? Color.white : Color.clear,
                            lineWidth: isFocused ? 4 : 0
                        )
                )
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            AsyncImage(url: URL(string: artwork.url)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 280, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                case .failure(_):
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.5))
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}