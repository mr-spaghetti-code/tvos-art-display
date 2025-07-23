//
//  ImageCache.swift
//  Digital Art Display
//
//  Created by Joao Fiadeiro on 7/14/25.
//

import SwiftUI
import Combine
import ImageIO

struct AnimatedImage {
    let images: [UIImage]
    let duration: Double
}

class ImageCache {
    static let shared = ImageCache()
    
    private var imageCache = NSCache<NSString, UIImage>()
    private var animatedCache = NSCache<NSString, NSData>()
    private let queue = DispatchQueue(label: "com.digitalartdisplay.imagecache", attributes: .concurrent)
    
    private init() {
        imageCache.countLimit = 6 // Further reduced - only keep ~6 images
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB (reduced from 100MB)
        animatedCache.countLimit = 3 // Further reduced - only keep ~3 GIFs
        animatedCache.totalCostLimit = 30 * 1024 * 1024 // 30MB for GIFs (reduced from 50MB)
    }
    
    func image(for url: String) -> UIImage? {
        queue.sync {
            imageCache.object(forKey: url as NSString)
        }
    }
    
    func animatedImageData(for url: String) -> Data? {
        queue.sync {
            animatedCache.object(forKey: url as NSString) as Data?
        }
    }
    
    func insertImage(_ image: UIImage, for url: String) {
        queue.async(flags: .barrier) {
            let cost = image.pngData()?.count ?? 0
            self.imageCache.setObject(image, forKey: url as NSString, cost: cost)
        }
    }
    
    func insertAnimatedImageData(_ data: Data, for url: String) {
        queue.async(flags: .barrier) {
            self.animatedCache.setObject(data as NSData, forKey: url as NSString, cost: data.count)
        }
    }
    
    func removeImage(for url: String) {
        queue.async(flags: .barrier) {
            self.imageCache.removeObject(forKey: url as NSString)
            self.animatedCache.removeObject(forKey: url as NSString)
        }
    }
    
    func removeAllImages() {
        queue.async(flags: .barrier) {
            self.imageCache.removeAllObjects()
            self.animatedCache.removeAllObjects()
        }
    }
}

class ImageLoaderManager {
    static let shared = ImageLoaderManager()
    
    private var loaders: [String: ImageLoader] = [:]
    private let queue = DispatchQueue(label: "com.digitalartdisplay.loadermanager", attributes: .concurrent)
    
    private init() {}
    
    func loader(for url: String) -> ImageLoader {
        queue.sync {
            if let existingLoader = loaders[url] {
                return existingLoader
            }
            
            let newLoader = ImageLoader()
            queue.async(flags: .barrier) {
                self.loaders[url] = newLoader
            }
            return newLoader
        }
    }
    
    func preloadImages(urls: [String]) {
        for url in urls {
            let loader = loader(for: url)
            loader.load(urlString: url)
        }
    }
    
    func preloadImagesWithProgress(urls: [String], progress: @escaping (Double) -> Void, completion: @escaping () -> Void) {
        guard !urls.isEmpty else {
            completion()
            return
        }
        
        let batchSize = 2 // Load only 2 images at a time to prevent memory issues on Apple TV devices
        var loadedCount = 0
        let totalCount = urls.count
        let lock = NSLock()
        
        // Create batches
        var batches: [[String]] = []
        for i in stride(from: 0, to: urls.count, by: batchSize) {
            let endIndex = min(i + batchSize, urls.count)
            batches.append(Array(urls[i..<endIndex]))
        }
        
        // Process batches sequentially
        func processBatch(at index: Int) {
            guard index < batches.count else {
                // All batches processed
                DispatchQueue.main.async {
                    completion()
                }
                return
            }
            
            let batch = batches[index]
            let group = DispatchGroup()
            
            for url in batch {
                let loader = loader(for: url)
                
                // Check if already cached
                if loader.image != nil || loader.animatedImageData != nil {
                    lock.lock()
                    loadedCount += 1
                    let currentProgress = Double(loadedCount) / Double(totalCount)
                    lock.unlock()
                    
                    DispatchQueue.main.async {
                        progress(currentProgress)
                    }
                    continue
                }
                
                // Load the image with completion tracking
                group.enter()
                loader.loadWithCompletion(urlString: url) { success in
                    lock.lock()
                    loadedCount += 1
                    let currentProgress = Double(loadedCount) / Double(totalCount)
                    lock.unlock()
                    
                    DispatchQueue.main.async {
                        progress(currentProgress)
                    }
                    
                    group.leave()
                }
            }
            
            // Wait for batch to complete before processing next batch
            group.notify(queue: .main) {
                // Small delay between batches to allow memory to settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    processBatch(at: index + 1)
                }
            }
        }
        
        // Start processing first batch
        processBatch(at: 0)
    }
    
    func prioritizedPreloadWithProgress(urls: [String], priorityIndices: [Int], progress: @escaping (Double) -> Void, completion: @escaping () -> Void) {
        guard !urls.isEmpty else {
            completion()
            return
        }
        
        // Create priority-ordered list
        var orderedUrls: [String] = []
        var remainingIndices = Set(0..<urls.count)
        
        // Add priority items first
        for index in priorityIndices where index < urls.count {
            orderedUrls.append(urls[index])
            remainingIndices.remove(index)
        }
        
        // Add remaining items
        for index in remainingIndices.sorted() {
            orderedUrls.append(urls[index])
        }
        
        // Use batch preloading with the ordered list
        preloadImagesWithProgress(urls: orderedUrls, progress: progress, completion: completion)
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var animatedImageData: Data?
    @Published var isLoading = false
    @Published var loadingProgress: Double = 0
    
    private var cancellable: AnyCancellable?
    private var currentUrlString: String?
    
    init() {}
    
    deinit {
        cancellable?.cancel()
    }
    
    func load(urlString: String) {
        // Don't reload if it's the same URL
        guard currentUrlString != urlString else { return }
        
        // Cancel any existing load
        cancellable?.cancel()
        
        currentUrlString = urlString
        
        // Check cache first
        if let cachedData = ImageCache.shared.animatedImageData(for: urlString) {
            self.animatedImageData = cachedData
            self.image = UIImage(data: cachedData)
            self.isLoading = false
            return
        } else if let cachedImage = ImageCache.shared.image(for: urlString) {
            self.image = cachedImage
            self.animatedImageData = nil
            self.isLoading = false
            return
        }
        
        // Load from network
        loadImage(urlString: urlString)
    }
    
    func loadWithCompletion(urlString: String, completion: @escaping (Bool) -> Void) {
        // Don't reload if it's the same URL
        guard currentUrlString != urlString else {
            completion(true)
            return
        }
        
        // Cancel any existing load
        cancellable?.cancel()
        
        currentUrlString = urlString
        
        // Check cache first
        if let cachedData = ImageCache.shared.animatedImageData(for: urlString) {
            self.animatedImageData = cachedData
            self.image = UIImage(data: cachedData)
            self.isLoading = false
            completion(true)
            return
        } else if let cachedImage = ImageCache.shared.image(for: urlString) {
            self.image = cachedImage
            self.animatedImageData = nil
            self.isLoading = false
            completion(true)
            return
        }
        
        // Load from network
        loadImageWithCompletion(urlString: urlString, completion: completion)
    }
    
    private func loadImage(urlString: String) {
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            self.image = nil
            self.animatedImageData = nil
            return
        }
        
        self.isLoading = true
        self.loadingProgress = 0
        self.image = nil
        self.animatedImageData = nil
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] data in
                guard let self = self else { return }
                
                // Make sure this is still the URL we want
                guard self.currentUrlString == urlString else { return }
                
                self.isLoading = false
                
                // Check if it's a GIF
                if self.isGIF(data: data) {
                    self.animatedImageData = data
                    self.image = UIImage(data: data)
                    ImageCache.shared.insertAnimatedImageData(data, for: urlString)
                } else if let downloadedImage = UIImage(data: data) {
                    self.image = downloadedImage
                    self.animatedImageData = nil
                    ImageCache.shared.insertImage(downloadedImage, for: urlString)
                }
            })
    }
    
    private func loadImageWithCompletion(urlString: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            self.image = nil
            self.animatedImageData = nil
            completion(false)
            return
        }
        
        self.isLoading = true
        self.loadingProgress = 0
        self.image = nil
        self.animatedImageData = nil
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                }
            },
                  receiveValue: { [weak self] data in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                // Make sure this is still the URL we want
                guard self.currentUrlString == urlString else {
                    completion(false)
                    return
                }
                
                self.isLoading = false
                
                // Check if it's a GIF
                if self.isGIF(data: data) {
                    self.animatedImageData = data
                    self.image = UIImage(data: data)
                    ImageCache.shared.insertAnimatedImageData(data, for: urlString)
                    completion(true)
                } else if let downloadedImage = UIImage(data: data) {
                    self.image = downloadedImage
                    self.animatedImageData = nil
                    ImageCache.shared.insertImage(downloadedImage, for: urlString)
                    completion(true)
                } else {
                    completion(false)
                }
            })
    }
    
    private func isGIF(data: Data) -> Bool {
        guard data.count > 3 else { return false }
        let gifSignature: [UInt8] = [0x47, 0x49, 0x46] // "GIF"
        let firstThreeBytes = data.prefix(3)
        return firstThreeBytes.elementsEqual(gifSignature)
    }
}

struct CachedAsyncImage: View {
    @State private var currentUrl: String
    @ObservedObject private var loader: ImageLoader
    let url: String
    let aspectRatio: ContentMode
    let animationSpeed: Double
    let onLoadingProgress: ((Double) -> Void)?
    
    init(url: String, aspectRatio: ContentMode = .fit, animationSpeed: Double = 1.0, onLoadingProgress: ((Double) -> Void)? = nil) {
        self.url = url
        self.aspectRatio = aspectRatio
        self.animationSpeed = animationSpeed
        self.onLoadingProgress = onLoadingProgress
        self._currentUrl = State(initialValue: url)
        self.loader = ImageLoaderManager.shared.loader(for: url)
    }
    
    var body: some View {
        Group {
            if let animatedData = loader.animatedImageData {
                AnimatedGIFWrapper(data: animatedData, contentMode: aspectRatio, animationSpeed: animationSpeed)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: aspectRatio)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else if loader.isLoading {
                LoadingView()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                Image(systemName: "photo.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.white.opacity(0.3))
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .onAppear {
            // Load only if not already loaded
            if loader.image == nil && loader.animatedImageData == nil && !loader.isLoading {
                loader.load(urlString: url)
            }
        }
        .onChange(of: url) { oldUrl, newUrl in
            // Only load if URL actually changed
            if oldUrl != newUrl {
                // Get the loader for the new URL and trigger load if needed
                let newLoader = ImageLoaderManager.shared.loader(for: newUrl)
                if newLoader.image == nil && newLoader.animatedImageData == nil && !newLoader.isLoading {
                    newLoader.load(urlString: newUrl)
                }
            }
        }
    }
}

struct AnimatedGIFView: UIViewRepresentable {
    let data: Data
    let animationSpeed: Double
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        if let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let count = CGImageSourceGetCount(source)
            var images: [UIImage] = []
            var totalDuration: Double = 0
            
            for i in 0..<count {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    let image = UIImage(cgImage: cgImage)
                    images.append(image)
                    
                    // Get frame duration
                    if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                       let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                       let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double {
                        totalDuration += frameDuration
                    } else {
                        totalDuration += 0.1 // Default frame duration
                    }
                }
            }
            
            if images.count > 1 {
                uiView.animationImages = images
                // Apply the speed multiplier (inverse relationship - higher speed = shorter duration)
                uiView.animationDuration = totalDuration / animationSpeed
                uiView.animationRepeatCount = 0 // Infinite
                uiView.startAnimating()
            } else if let firstImage = images.first {
                uiView.image = firstImage
            }
        }
    }
}

struct AnimatedGIFWrapper: View {
    let data: Data
    let contentMode: ContentMode
    let animationSpeed: Double
    
    var body: some View {
        GeometryReader { geometry in
            AnimatedGIFView(data: data, animationSpeed: animationSpeed)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.1)
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.white, .white.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                        .animation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                
                Text("Loading artwork...")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}