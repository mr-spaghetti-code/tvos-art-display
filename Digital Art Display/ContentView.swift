//
//  ContentView.swift
//  Digital Art Display
//
//  Created by Joao Fiadeiro on 7/14/25.
//

import SwiftUI

// Note: ImageCache.swift contains ImageLoaderManager and CachedAsyncImage
// Linter errors about these types not being in scope are false positives
// The types are available when building in Xcode

// Note: Models are now defined in Models.swift

// Extension for placeholder functionality
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct ContentView: View {
    @StateObject private var galleryManager = GalleryManager()
    @State private var selectedIndex = 0
    @State private var showGallery = false
    @State private var showSettings = false
    @State private var showQRCode = true
    @FocusState private var galleryFocused: Bool
    @FocusState private var settingsFocused: Bool
    @FocusState private var focusedIndex: Int?
    @FocusState private var qrCodeFocused: Bool
    
    // Polling timer
    @State private var pollingTimer: Timer?
    
    // Background color state
    @State private var backgroundColor: Color = .black
    @State private var selectedColorIndex = 0
    @FocusState private var backgroundColorFocused: Bool
    
    // Smart blur state
    @State private var smartBlurEnabled = false
    @FocusState private var smartBlurFocused: Bool
    
    // GIF animation speed state
    @State private var gifAnimationSpeed: Double = 1.0
    @FocusState private var gifSpeedFocused: Bool
    
    // Refresh button state
    @FocusState private var refreshButtonFocused: Bool
    
    // Reset button state
    @FocusState private var resetButtonFocused: Bool
    
    // Gallery ID entry modal state
    @State private var showGalleryIdModal = false
    @State private var enteredGalleryId = ""
    @FocusState private var galleryIdFieldFocused: Bool
    
    // Gallery scroll debounce timer
    @State private var galleryScrollTimer: Timer?
    
    // Track loaded thumbnail indices
    @State private var loadedThumbnailIndices = Set<Int>()
    
    // Available background colors
    let backgroundColors: [(name: String, color: Color)] = [
        ("Black", .black),
        ("Dark Gray", Color(white: 0.15)),
        ("Navy Blue", Color(red: 0.05, green: 0.05, blue: 0.2)),
        ("Dark Green", Color(red: 0.05, green: 0.15, blue: 0.05)),
        ("Dark Purple", Color(red: 0.15, green: 0.05, blue: 0.2)),
        ("Burgundy", Color(red: 0.2, green: 0.05, blue: 0.05)),
        ("Dark Teal", Color(red: 0.05, green: 0.15, blue: 0.15))
    ]
    
    var artworks: [ArtworkItem] {
        return galleryManager.galleryArtworks
    }
    
    var body: some View {
        ZStack {
            // Background layer
            if smartBlurEnabled && !artworks.isEmpty && !showQRCode && galleryManager.preloadProgress >= 0.2 {
                // Smart blur background using current artwork
                GeometryReader { geometry in
                    CachedAsyncImage(
                        url: artworks[selectedIndex].url,
                        aspectRatio: .fill,
                        animationSpeed: gifAnimationSpeed
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .blur(radius: 80)
                    .overlay(
                        // Dark overlay to ensure main image stands out
                        Color.black.opacity(0.5)
                    )
                    .scaleEffect(1.2) // Slight scale to avoid edge artifacts
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: selectedIndex)
            } else {
                backgroundColor
                    .ignoresSafeArea()
            }
            
            // Loading screen with progress bar (when gallery is loading but images aren't ready)
            if !showQRCode && !artworks.isEmpty && galleryManager.isPreloadingImages && galleryManager.preloadProgress < 0.2 {
                // Only show loading screen while initial batch is loading (first 20%)
                PreloadingView(progress: galleryManager.preloadProgress)
                    .transition(.opacity)
            } else if showQRCode || artworks.isEmpty {
                // QR Code display (when no gallery is loaded)
                QRCodeView(
                    humanReadableId: galleryManager.humanReadableId,
                    galleryUrl: galleryManager.galleryUrl,
                    isFocused: $qrCodeFocused,
                    onTriggerPressed: {
                        showGalleryIdModal = true
                        enteredGalleryId = ""
                        galleryIdFieldFocused = true
                    }
                )
                .environmentObject(galleryManager)
                .transition(.opacity)
                .onAppear {
                    qrCodeFocused = true
                }
            } else if !artworks.isEmpty && galleryManager.preloadProgress >= 0.2 {
                // Main image display (show when initial batch is loaded - 20% progress)
                GeometryReader { geometry in
                    CachedAsyncImage(
                        url: artworks[selectedIndex].url,
                        aspectRatio: .fit,
                        animationSpeed: gifAnimationSpeed
                    )
                    .frame(maxWidth: geometry.size.width * 0.85, maxHeight: geometry.size.height * 0.85)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .animation(.easeInOut(duration: 0.3), value: selectedIndex)
                .ignoresSafeArea()
                .focusable(!showGallery && !showSettings)
                .onMoveCommand { direction in
                    if !showGallery && !showSettings {
                        switch direction {
                        case .left:
                            if selectedIndex > 0 {
                                selectedIndex -= 1
                                // Clear distant images when navigating
                                cleanupDistantImages()
                            }
                        case .right:
                            if selectedIndex < artworks.count - 1 {
                                selectedIndex += 1
                                // Clear distant images when navigating
                                cleanupDistantImages()
                            }
                        case .up:
                            withAnimation {
                                showGallery = true
                                focusedIndex = selectedIndex
                                galleryFocused = true
                            }
                        case .down:
                            withAnimation {
                                showSettings = true
                                settingsFocused = true
                                // Initialize settings focus to the first item
                                backgroundColorFocused = true
                                smartBlurFocused = false
                                gifSpeedFocused = false
                                refreshButtonFocused = false
                                resetButtonFocused = false
                            }
                        default:
                            break
                        }
                    }
                }
                
                // Artwork info overlay (bottom-right)
                if !showGallery && !showSettings && galleryManager.preloadProgress >= 0.2 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ArtworkInfoPanel(artwork: artworks[selectedIndex])
                                .padding(.trailing, 60)
                                .padding(.bottom, 40)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedIndex)
                }
            }
            
            // Gallery overlay
            VStack {
                Spacer()
                
                if showGallery && !artworks.isEmpty && galleryManager.preloadProgress >= 0.2 {
                    VStack(spacing: 0) {
                        // Gallery title
                        Text("Select Artwork")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            ScrollViewReader { proxy in
                                LazyHStack(spacing: 30, pinnedViews: []) {
                                    ForEach(artworks.indices, id: \.self) { index in
                                        GalleryThumbnail(
                                            artwork: artworks[index],
                                            isSelected: index == selectedIndex,
                                            isFocused: focusedIndex == index,
                                            index: index,
                                            animationSpeed: gifAnimationSpeed,
                                            selectedIndex: selectedIndex
                                        )
                                        .id(index)
                                        .focusable(true, interactions: .activate)
                                        .focused($focusedIndex, equals: index)
                                        .onTapGesture {
                                            selectedIndex = index
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                showGallery = false
                                                galleryFocused = false
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 80)
                                .onAppear {
                                    proxy.scrollTo(selectedIndex, anchor: .center)
                                }
                                .onChange(of: focusedIndex) { _, newValue in
                                    if let newValue = newValue {
                                        withAnimation {
                                            proxy.scrollTo(newValue, anchor: .center)
                                        }
                                        
                                        // Cancel previous timer
                                        galleryScrollTimer?.invalidate()
                                        
                                        // Debounce preloading to avoid loading during rapid scrolling
                                        galleryScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                                            // Define the window of images to keep in memory
                                            let windowSize = 2 // Keep current ± 2 images only
                                            let keepRange = max(0, newValue - windowSize)...min(artworks.count - 1, newValue + windowSize)
                                            
                                            // First, aggressively remove ALL images outside the window
                                            for (index, artwork) in artworks.enumerated() {
                                                if !keepRange.contains(index) {
                                                    ImageCache.shared.removeImage(for: artwork.url)
                                                    loadedThumbnailIndices.remove(index)
                                                }
                                            }
                                            
                                            // Force the cache to clear if we have too many loaded
                                            if loadedThumbnailIndices.count > (windowSize * 2 + 1) {
                                                // Clear everything except the keep range
                                                loadedThumbnailIndices = loadedThumbnailIndices.filter { keepRange.contains($0) }
                                            }
                                            
                                            // Then preload only what's needed within the window
                                            for preloadIndex in keepRange {
                                                if !loadedThumbnailIndices.contains(preloadIndex) {
                                                    let loader = ImageLoaderManager.shared.loader(for: artworks[preloadIndex].url)
                                                    if loader.image == nil && loader.animatedImageData == nil && !loader.isLoading {
                                                        loader.load(urlString: artworks[preloadIndex].url)
                                                        loadedThumbnailIndices.insert(preloadIndex)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: 250)
                        .focused($galleryFocused)
                        .onMoveCommand { direction in
                            if direction == .down {
                                withAnimation {
                                    showGallery = false
                                    galleryFocused = false
                                }
                            }
                        }
                    }
                    .padding(.vertical, 40)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0),
                                Color.black.opacity(0.95)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        focusedIndex = selectedIndex
                        galleryFocused = true
                        
                        // Ensure we start with a clean slate
                        cleanupDistantImages()
                        loadedThumbnailIndices.removeAll()
                        
                        // Only track the initially visible items
                        let initialRange = max(0, selectedIndex - 2)...min(artworks.count - 1, selectedIndex + 2)
                        for index in initialRange {
                            loadedThumbnailIndices.insert(index)
                        }
                    }
                    .onDisappear {
                        // Cancel any pending scroll timer
                        galleryScrollTimer?.invalidate()
                        galleryScrollTimer = nil
                        
                        // Clear loaded indices tracking
                        loadedThumbnailIndices.removeAll()
                        
                        // Clear image cache for thumbnails when gallery closes to free memory
                        // Keep only the currently selected image
                        for (index, artwork) in artworks.enumerated() {
                            if index != selectedIndex {
                                ImageCache.shared.removeImage(for: artwork.url)
                            }
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showGallery)
            
            // Settings overlay
            if showSettings && !artworks.isEmpty && galleryManager.preloadProgress >= 0.2 {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 25) {
                        Text("Settings")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(.bottom, 15)
                        
                        VStack(spacing: 20) {
                            ColorPickerRow(
                                title: "Background Color",
                                selectedColorIndex: $selectedColorIndex,
                                colors: backgroundColors,
                                isFocused: $backgroundColorFocused,
                                onColorChange: { newColor in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        backgroundColor = newColor
                                    }
                                }
                            )
                            
                            SmartBlurToggle(
                                title: "Smart Blur",
                                isEnabled: $smartBlurEnabled,
                                isFocused: $smartBlurFocused
                            )
                            
                            GIFSpeedSlider(
                                title: "GIF Animation Speed",
                                speed: $gifAnimationSpeed,
                                isFocused: $gifSpeedFocused
                            )
                            
                            RefreshGalleryButton(
                                galleryManager: galleryManager,
                                isFocused: $refreshButtonFocused
                            )
                            
                            ResetGalleryButton(
                                galleryManager: galleryManager,
                                isFocused: $resetButtonFocused,
                                onReset: {
                                    // Reset gallery and show QR code
                                    galleryManager.resetGallery()
                                    withAnimation {
                                        showQRCode = true
                                        qrCodeFocused = true
                                        showSettings = false
                                        // Focus states will be cleared by the parent when settings close
                                    }
                                    // Start polling again
                                    startPolling()
                                }
                            )
                        }
                        .padding(.horizontal, 100)
                        .onMoveCommand { direction in
                            // Ensure only one focus state is true at a time
                            if direction == .up {
                                if resetButtonFocused {
                                    resetButtonFocused = false
                                    refreshButtonFocused = true
                                } else if refreshButtonFocused {
                                    refreshButtonFocused = false
                                    gifSpeedFocused = true
                                } else if gifSpeedFocused {
                                    gifSpeedFocused = false
                                    smartBlurFocused = true
                                } else if smartBlurFocused {
                                    smartBlurFocused = false
                                    backgroundColorFocused = true
                                } else if backgroundColorFocused {
                                    // Close settings when at the top
                                    withAnimation {
                                        showSettings = false
                                        backgroundColorFocused = false
                                    }
                                }
                            } else if direction == .down {
                                if backgroundColorFocused {
                                    backgroundColorFocused = false
                                    smartBlurFocused = true
                                } else if smartBlurFocused {
                                    smartBlurFocused = false
                                    gifSpeedFocused = true
                                } else if gifSpeedFocused {
                                    gifSpeedFocused = false
                                    refreshButtonFocused = true
                                } else if refreshButtonFocused {
                                    refreshButtonFocused = false
                                    resetButtonFocused = true
                                } else if resetButtonFocused {
                                    // Bottom of settings - do nothing
                                }
                            }
                        }
                    }
                    .padding(.vertical, 60)
                    .frame(maxWidth: 1200)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.black.opacity(0.95))
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    // Focus on the color picker when settings appear
                    backgroundColorFocused = true
                }
                .animation(.easeInOut(duration: 0.3), value: showSettings)
            }
            
            // Gallery ID Entry Modal
            if showGalleryIdModal {
                ZStack {
                    // Background overlay
                    Color.black.opacity(0.75)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showGalleryIdModal = false
                                galleryIdFieldFocused = false
                                qrCodeFocused = true
                            }
                        }
                    
                    VStack(spacing: 40) {
                        Text("Enter Gallery ID")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.white)
                        
                        VStack(spacing: 16) {
                            // Text field for gallery ID
                            TextField("", text: $enteredGalleryId)
                                .placeholder(when: enteredGalleryId.isEmpty, alignment: .center) {
                                    Text("Gallery ID")
                                        .foregroundColor(.white.opacity(0.3))
                                        .font(.system(size: 28, weight: .regular, design: .rounded))
                                }
                                .font(.system(size: 28, weight: .regular, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(PlainTextFieldStyle())
                                .focused($galleryIdFieldFocused)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(.vertical, 20)
                                .padding(.horizontal, 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            galleryIdFieldFocused ? Color.white.opacity(0.4) : Color.white.opacity(0.2),
                                            lineWidth: 1
                                        )
                                )
                                .frame(width: 500)
                                .onSubmit {
                                    let normalizedId = enteredGalleryId
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                        .lowercased()
                                        .replacingOccurrences(of: " ", with: "")
                                    if !normalizedId.isEmpty {
                                        galleryManager.humanReadableId = normalizedId
                                        galleryManager.loadGallery()
                                        withAnimation {
                                            showGalleryIdModal = false
                                            galleryIdFieldFocused = false
                                        }
                                    }
                                }
                            
                            Text("Enter the ID shared with you (spaces and caps OK)")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        HStack(spacing: 20) {
                            // Cancel button
                            Button(action: {
                                withAnimation {
                                    showGalleryIdModal = false
                                    galleryIdFieldFocused = false
                                    qrCodeFocused = true
                                }
                            }) {
                                Text("Cancel")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(width: 140, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Load button
                            Button(action: {
                                let normalizedId = enteredGalleryId
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .lowercased()
                                    .replacingOccurrences(of: " ", with: "")
                                if !normalizedId.isEmpty {
                                    galleryManager.humanReadableId = normalizedId
                                    galleryManager.loadGallery()
                                    withAnimation {
                                        showGalleryIdModal = false
                                        galleryIdFieldFocused = false
                                    }
                                }
                            }) {
                                Text("Load Gallery")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(enteredGalleryId.isEmpty ? .white.opacity(0.3) : .black.opacity(0.9))
                                    .frame(width: 140, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(enteredGalleryId.isEmpty ? Color.clear : Color.white.opacity(0.95))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        enteredGalleryId.isEmpty ? Color.white.opacity(0.1) : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(enteredGalleryId.isEmpty)
                        }
                        .padding(.top, 10)
                    }
                    .padding(50)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.black.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.15),
                                                Color.white.opacity(0.05)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 60, x: 0, y: 10)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showGalleryIdModal)
            }
        }
        .onMoveCommand { direction in
            // This handles edge cases where focus might be on the root view
            if !showGallery && !showSettings && !artworks.isEmpty && galleryManager.preloadProgress >= 0.2 {
                if direction == .up {
                    withAnimation {
                        showGallery = true
                        focusedIndex = selectedIndex
                        galleryFocused = true
                    }
                } else if direction == .down {
                    withAnimation {
                        showSettings = true
                        backgroundColorFocused = true
                        // Clear any other settings focus states
                        smartBlurFocused = false
                        gifSpeedFocused = false
                        refreshButtonFocused = false
                        resetButtonFocused = false
                    }
                }
            }
        }
        .onPlayPauseCommand {
            withAnimation {
                if showSettings {
                    showSettings = false
                    // Clear all settings focus states
                    backgroundColorFocused = false
                    smartBlurFocused = false
                    gifSpeedFocused = false
                    refreshButtonFocused = false
                    resetButtonFocused = false
                } else if !artworks.isEmpty && galleryManager.preloadProgress >= 0.2 {
                    showGallery.toggle()
                    if showGallery {
                        focusedIndex = selectedIndex
                        galleryFocused = true
                    } else {
                        galleryFocused = false
                    }
                }
            }
        }
        .onExitCommand {
            if showGalleryIdModal {
                withAnimation {
                    showGalleryIdModal = false
                    galleryIdFieldFocused = false
                    qrCodeFocused = true
                }
            } else if showGallery {
                withAnimation {
                    showGallery = false
                    galleryFocused = false
                }
            } else if showSettings {
                withAnimation {
                    showSettings = false
                    // Clear all settings focus states
                    backgroundColorFocused = false
                    smartBlurFocused = false
                    gifSpeedFocused = false
                    refreshButtonFocused = false
                    resetButtonFocused = false
                }
            }
        }
        .onAppear {
            // galleryManager.humanReadableId = "sweet-baby-jesus"
            galleryManager.loadGallery()
            startPolling()
            
            // Listen for memory warnings
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { _ in
                // Aggressively clear cache on memory warning
                ImageCache.shared.removeAllImages()
                loadedThumbnailIndices.removeAll()
                
                // Only keep the current image
                if !artworks.isEmpty {
                    let loader = ImageLoaderManager.shared.loader(for: artworks[selectedIndex].url)
                    loader.load(urlString: artworks[selectedIndex].url)
                }
            }
        }
        .onDisappear {
            stopPolling()
        }
        .onChange(of: galleryManager.galleryArtworks) {
            if !galleryManager.galleryArtworks.isEmpty && showQRCode {
                withAnimation {
                    showQRCode = false
                    qrCodeFocused = false
                }
                // Stop polling once we have a gallery
                stopPolling()
            }
        }
        .onChange(of: showQRCode) { _, newValue in
            if newValue {
                // Start polling when QR code is shown
                startPolling()
            } else {
                // Stop polling when QR code is hidden
                stopPolling()
            }
        }
    }
    
    private func startPolling() {
        // Stop any existing timer
        stopPolling()
        
        // Only poll if QR code is showing and we don't have artworks
        guard showQRCode && galleryManager.galleryArtworks.isEmpty else { return }
        
        // Poll every 2 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if showQRCode && galleryManager.galleryArtworks.isEmpty {
                galleryManager.loadGallery()
            } else {
                stopPolling()
            }
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func cleanupDistantImages() {
        // Keep only images very close to current selection
        let keepRange = max(0, selectedIndex - 1)...min(artworks.count - 1, selectedIndex + 1)
        
        for (index, artwork) in artworks.enumerated() {
            if !keepRange.contains(index) {
                ImageCache.shared.removeImage(for: artwork.url)
            }
        }
    }
}

struct QRCodeView: View {
    let humanReadableId: String
    let galleryUrl: String
    @FocusState.Binding var isFocused: Bool
    let onTriggerPressed: () -> Void
    @EnvironmentObject var galleryManager: GalleryManager
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Scan to Create Your Gallery")
                .font(.largeTitle)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            if let qrImage = QRCodeGenerator.generate(from: galleryUrl) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 400)
                    .padding(40)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .white.opacity(0.2), radius: 20)
                    .scaleEffect(isFocused ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            }
            
            VStack(spacing: 16) {
                Text("Gallery ID")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(humanReadableId)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            VStack(spacing: 12) {
                Text("Visit \(galleryUrl)")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.5))
                
                // Status indicator
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                    
                    Text("Waiting for gallery creation...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 8)
                
                Text("Press Play/Pause for new Gallery ID")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                
                Text("Press Select to enter Gallery ID")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(60)
        .focusable(true)
        .focused($isFocused)
        .onPlayPauseCommand {
            // Generate new gallery ID
            galleryManager.generateNewId()
        }
        .onTapGesture {
            onTriggerPressed()
        }
    }
}

struct GalleryThumbnail: View {
    let artwork: ArtworkItem
    let isSelected: Bool
    let isFocused: Bool
    let index: Int
    let animationSpeed: Double
    let selectedIndex: Int
    
    // Track if this thumbnail should load its image
    @State private var shouldLoadImage = false
    
    // Compute if image should be shown based on distance
    private var shouldShowImage: Bool {
        let distance = abs(index - selectedIndex)
        return distance <= 3 // Only show images within 3 positions
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(isSelected ? 0.2 : 0.1))
                .frame(width: 300, height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isFocused ? Color.white : Color.clear,
                            lineWidth: isFocused ? 4 : 0
                        )
                )
                .scaleEffect(isFocused ? 1.15 : 1.0)
                .shadow(color: isFocused ? .white.opacity(0.5) : .clear, radius: 20)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            // Container for the image with proper aspect ratio fitting
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.3))
                .frame(width: 280, height: 180)
                .overlay(
                    Group {
                        if shouldLoadImage && shouldShowImage {
                            CachedAsyncImage(
                                url: artwork.url,
                                aspectRatio: .fit,
                                animationSpeed: animationSpeed
                            )
                            .frame(maxWidth: 280, maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        } else {
                            // Show placeholder while not loaded
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .onAppear {
            updateLoadingState()
        }
        .onChange(of: selectedIndex) { _, _ in
            updateLoadingState()
        }
        .onChange(of: isFocused) { _, newValue in
            // Ensure focused items are loaded immediately
            if newValue && !shouldLoadImage {
                shouldLoadImage = true
            }
        }
    }
    
    private func updateLoadingState() {
        let distance = abs(index - selectedIndex)
        
        if distance <= 2 {
            // Load immediately for nearby items
            shouldLoadImage = true
        } else if distance > 3 {
            // Unload distant items
            shouldLoadImage = false
            // Also remove from cache to free memory
            ImageCache.shared.removeImage(for: artwork.url)
        } else if !shouldLoadImage {
            // Delay loading for items at edge of window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if abs(index - selectedIndex) <= 3 {
                    shouldLoadImage = true
                }
            }
        }
    }
}

struct SettingsRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.title3)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct ColorPickerRow: View {
    let title: String
    @Binding var selectedColorIndex: Int
    let colors: [(name: String, color: Color)]
    @FocusState.Binding var isFocused: Bool
    let onColorChange: (Color) -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(minWidth: 200, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 20) {
                ForEach(0..<colors.count, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(colors[index].color)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedColorIndex == index && isFocused ? Color.white : Color.white.opacity(0.3),
                                        lineWidth: selectedColorIndex == index ? 3 : 1.5
                                    )
                            )
                            .scaleEffect(selectedColorIndex == index && isFocused ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: selectedColorIndex)
                            .animation(.easeInOut(duration: 0.15), value: isFocused)
                        
                        if selectedColorIndex == index {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2, x: 0, y: 0)
                        }
                    }
                }
            }
            
            Text(colors[selectedColorIndex].name)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.white)
                .frame(minWidth: 150, alignment: .trailing)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isFocused ? 0.2 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isFocused ? Color.white : Color.clear, lineWidth: 2)
                )
        )
        .focusable(true)
        .focused($isFocused)
        .onMoveCommand { direction in
            if isFocused {
                switch direction {
                case .left:
                    if selectedColorIndex > 0 {
                        selectedColorIndex -= 1
                        onColorChange(colors[selectedColorIndex].color)
                    }
                case .right:
                    if selectedColorIndex < colors.count - 1 {
                        selectedColorIndex += 1
                        onColorChange(colors[selectedColorIndex].color)
                    }
                case .up, .down:
                    // Allow navigation to pass through to parent
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}

struct ArtworkInfoPanel: View {
    let artwork: ArtworkItem
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let name = artwork.metadata.name {
                Text(name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            
            if let description = artwork.metadata.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.75),
                            Color.black.opacity(0.55)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: 450)
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

struct SmartBlurToggle: View {
    let title: String
    @Binding var isEnabled: Bool
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(minWidth: 200, alignment: .leading)
            
            Spacer()
            
            // Custom toggle switch
            ZStack {
                Capsule()
                    .fill(isEnabled ? Color.blue : Color.white.opacity(0.3))
                    .frame(width: 60, height: 32)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .offset(x: isEnabled ? 14 : -14)
                    .animation(.easeInOut(duration: 0.2), value: isEnabled)
            }
            .overlay(
                Capsule()
                    .stroke(isFocused ? Color.white : Color.clear, lineWidth: 2)
                    .frame(width: 64, height: 36)
            )
            
            Text(isEnabled ? "On" : "Off")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.white)
                .frame(minWidth: 150, alignment: .trailing)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isFocused ? 0.2 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isFocused ? Color.white : Color.clear, lineWidth: 2)
                )
        )
        .focusable(true)
        .focused($isFocused)
        .onMoveCommand { direction in
            if isFocused {
                switch direction {
                case .left, .right:
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEnabled.toggle()
                    }
                case .up, .down:
                    // Allow navigation to pass through to parent
                    break
                @unknown default:
                    break
                }
            }
        }
        .onPlayPauseCommand {
            if isFocused {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isEnabled.toggle()
                }
            }
        }
    }
}

struct GIFSpeedSlider: View {
    let title: String
    @Binding var speed: Double
    @FocusState.Binding var isFocused: Bool
    
    // Speed presets
    let speedPresets: [(label: String, value: Double)] = [
        ("0.25x", 0.25),
        ("0.5x", 0.5),
        ("0.75x", 0.75),
        ("1x", 1.0),
        ("1.25x", 1.25),
        ("1.5x", 1.5),
        ("2x", 2.0)
    ]
    
    var currentSpeedIndex: Int {
        speedPresets.firstIndex(where: { abs($0.value - speed) < 0.01 }) ?? 3 // Default to 1x
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(minWidth: 200, alignment: .leading)
            
            Spacer()
            
            // Speed indicator with left/right arrows
            HStack(spacing: 20) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(currentSpeedIndex > 0 && isFocused ? 0.8 : 0.3))
                
                Text(speedPresets[currentSpeedIndex].label)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 80)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(currentSpeedIndex < speedPresets.count - 1 && isFocused ? 0.8 : 0.3))
            }
            
            Spacer()
            
            // Visual speed indicator
            HStack(spacing: 3) {
                ForEach(0..<speedPresets.count, id: \.self) { index in
                    Rectangle()
                        .fill(index <= currentSpeedIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: index == currentSpeedIndex ? 18 : 12)
                        .animation(.easeInOut(duration: 0.15), value: currentSpeedIndex)
                }
            }
            .frame(minWidth: 150, alignment: .trailing)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isFocused ? 0.2 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isFocused ? Color.white : Color.clear, lineWidth: 2)
                )
        )
        .focusable(true)
        .focused($isFocused)
        .onMoveCommand { direction in
            if isFocused {
                switch direction {
                case .left:
                    if currentSpeedIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            speed = speedPresets[currentSpeedIndex - 1].value
                        }
                    }
                case .right:
                    if currentSpeedIndex < speedPresets.count - 1 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            speed = speedPresets[currentSpeedIndex + 1].value
                        }
                    }
                case .up, .down:
                    // Allow navigation to pass through to parent
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}

struct RefreshGalleryButton: View {
    let galleryManager: GalleryManager
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Refresh Gallery")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(minWidth: 200, alignment: .leading)
            
            Spacer()
            
            if galleryManager.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                    .frame(minWidth: 150, alignment: .trailing)
            } else {
                Spacer()
                    .frame(minWidth: 150)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isFocused ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isFocused ? Color.white : Color.clear, lineWidth: 2)
                )
        )
        .focusable(true)
        .focused($isFocused)
        .onMoveCommand { direction in
            if isFocused {
                switch direction {
                case .up, .down:
                    // Let parent handle vertical navigation
                    break
                case .left, .right:
                    // Buttons don't use horizontal navigation
                    break
                @unknown default:
                    break
                }
            }
        }
        .onPlayPauseCommand {
            if isFocused {
                galleryManager.refreshGallery()
            }
        }
    }
}

struct ResetGalleryButton: View {
    let galleryManager: GalleryManager
    @FocusState.Binding var isFocused: Bool
    let onReset: () -> Void
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Reset Gallery")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(minWidth: 200, alignment: .leading)
            
            Spacer()
            
            Spacer()
                .frame(minWidth: 150)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isFocused ? Color.red.opacity(0.3) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isFocused ? Color.white : Color.clear, lineWidth: 2)
                )
        )
        .focusable(true)
        .focused($isFocused)
        .onMoveCommand { direction in
            if isFocused {
                switch direction {
                case .up, .down:
                    // Let parent handle vertical navigation
                    break
                case .left, .right:
                    // Buttons don't use horizontal navigation
                    break
                @unknown default:
                    break
                }
            }
        }
        .onPlayPauseCommand {
            if isFocused {
                onReset()
            }
        }
    }
}

struct PreloadingView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("Loading Gallery")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.white)
                
                VStack(spacing: 20) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 20)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.9),
                                            Color.white.opacity(0.7)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 20)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 20)
                    .frame(maxWidth: 600)
                    
                    // Progress percentage
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text("Preparing your artworks...")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(60)
        }
    }
}

#Preview {
    ContentView()
}
