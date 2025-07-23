//
//  GalleryManager.swift
//  Digital Art Display
//
//  Created by Joao Fiadeiro on 7/14/25.
//

import Foundation
import Combine

// NOTE: You'll need to add the Supabase Swift SDK via Swift Package Manager
// Add: https://github.com/supabase/supabase-swift
// Then uncomment the import below:
import Supabase

@MainActor
class GalleryManager: ObservableObject {
    @Published var currentGallery: Gallery?
    @Published var galleryArtworks: [ArtworkItem] = []
    @Published var isLoading = false
    @Published var humanReadableId: String = ""
    
    // Preloading state
    @Published var isPreloadingImages = false
    @Published var preloadProgress: Double = 0.0
    @Published var allImagesPreloaded = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private let client: SupabaseClient
    
    // UserDefaults key for persisting gallery ID
    private let galleryIdKey = "com.digitalartdisplay.lastGalleryId"
    
    init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
        
        // Try to load saved gallery ID, otherwise generate a new one
        if let savedId = UserDefaults.standard.string(forKey: galleryIdKey), !savedId.isEmpty {
            self.humanReadableId = savedId
            print("Loaded saved gallery ID: \(savedId)")
        } else {
            self.humanReadableId = HumanReadableID.generate()
            print("Generated new gallery ID: \(self.humanReadableId)")
        }
    }
    
    // Save gallery ID to UserDefaults
    private func saveGalleryId() {
        UserDefaults.standard.set(humanReadableId, forKey: galleryIdKey)
        print("Saved gallery ID: \(humanReadableId)")
    }
    
    func loadGallery() {
        guard !isLoading else { return }
        
        Task {
            await checkGallery()
        }
    }
    
    func refreshGallery() {
        Task {
            await checkGallery()
        }
    }
    
    private func checkGallery() async {
        await MainActor.run {
            self.isLoading = true
            self.allImagesPreloaded = false
        }
        
        do {
            let response = try await client
                .from("galleries")
                .select()
                .eq("human_readable_id", value: humanReadableId)
                .single()
                .execute()
            
            // Print raw JSON for debugging
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("Raw JSON response: \(jsonString)")
            }
            
            let decoder = JSONDecoder()
            
            // Custom date formatter to handle fractional seconds
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try with fractional seconds first
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                // Try standard ISO8601 without fractional seconds
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                // Try with 'Z' suffix
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
            }
            
            do {
                // First, let's try to decode just to see the structure
                if let json = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
                    print("JSON structure keys: \(json.keys)")
                    if let artworksArray = json["artworks"] as? [[String: Any]], let firstArtwork = artworksArray.first {
                        print("First artwork keys: \(firstArtwork.keys)")
                        if let metadata = firstArtwork["metadata"] as? [String: Any] {
                            print("First artwork metadata keys: \(metadata.keys)")
                        }
                    }
                }
                
                let gallery = try decoder.decode(Gallery.self, from: response.data)
                await MainActor.run {
                    self.currentGallery = gallery
                    
                    // If artworks were added, update the display
                    if let artworks = gallery.artworks, !artworks.isEmpty {
                        self.galleryArtworks = artworks
                        
                        // Start preloading images with progress tracking
                        self.isPreloadingImages = true
                        self.preloadProgress = 0.0
                        
                        let imageUrls = artworks.map { $0.url }
                        // Create priority indices: load only first 2 images to start faster
                        let priorityIndices = Array(0..<min(2, imageUrls.count))
                        
                        ImageLoaderManager.shared.prioritizedPreloadWithProgress(
                            urls: imageUrls,
                            priorityIndices: priorityIndices,
                            progress: { [weak self] progress in
                                Task { @MainActor in
                                    self?.preloadProgress = progress
                                }
                            },
                            completion: { [weak self] in
                                Task { @MainActor in
                                    self?.isPreloadingImages = false
                                    self?.allImagesPreloaded = true
                                    // Save the gallery ID when successfully loaded with artworks
                                    self?.saveGalleryId()
                                }
                            }
                        )
                    }
                }
                
                // Update last_accessed_at
                if gallery.artworks != nil {
                    try? await updateLastAccessed()
                }
            } catch let decodingError {
                print("Decoding error: \(decodingError)")
                if let decodingError = decodingError as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("Type mismatch for type \(type) at path: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("Value not found for type \(type) at path: \(context.codingPath)")
                    case .keyNotFound(let key, let context):
                        print("Key '\(key)' not found at path: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("Data corrupted at path: \(context.codingPath)")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
            }
        } catch {
            print("Error checking gallery: \(error)")
            
            // For testing with the existing gallery
            if humanReadableId == "sweet-baby-jesus" {
                // Simulate loading artworks from the test gallery
                await MainActor.run {
                    // Load artworks from the existing artworks.json for testing
                    if let url = Bundle.main.url(forResource: "artworks", withExtension: "json"),
                       let data = try? Data(contentsOf: url),
                       let allArtworks = try? JSONDecoder().decode([ArtworkItem].self, from: data) {
                        
                        // Select 10 random artworks
                        let shuffled = allArtworks.shuffled()
                        self.galleryArtworks = Array(shuffled.prefix(10))
                        
                        // Start preloading images with progress tracking
                        self.isPreloadingImages = true
                        self.preloadProgress = 0.0
                        
                        let imageUrls = self.galleryArtworks.map { $0.url }
                        // Create priority indices: load only first 2 images to start faster
                        let priorityIndices = Array(0..<min(2, imageUrls.count))
                        
                        ImageLoaderManager.shared.prioritizedPreloadWithProgress(
                            urls: imageUrls,
                            priorityIndices: priorityIndices,
                            progress: { [weak self] progress in
                                Task { @MainActor in
                                    self?.preloadProgress = progress
                                }
                            },
                            completion: { [weak self] in
                                Task { @MainActor in
                                    self?.isPreloadingImages = false
                                    self?.allImagesPreloaded = true
                                    // Save the gallery ID when successfully loaded with artworks
                                    self?.saveGalleryId()
                                }
                            }
                        )
                    }
                }
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    private func updateLastAccessed() async throws {
        guard let galleryId = currentGallery?.id else { return }
        
        try await client
            .from("galleries")
            .update(["last_accessed_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: galleryId.uuidString)
            .execute()
    }
    
    func generateNewId() {
        humanReadableId = HumanReadableID.generate()
        currentGallery = nil
        galleryArtworks = []
        
        // Clear the saved ID since we're generating a new one
        UserDefaults.standard.removeObject(forKey: galleryIdKey)
        print("Cleared saved gallery ID and generated new ID: \(humanReadableId)")
        
        // Load gallery with new ID
        loadGallery()
    }
    
    func resetGallery() {
        // Clear the saved gallery ID
        UserDefaults.standard.removeObject(forKey: galleryIdKey)
        
        // Clear current gallery data
        currentGallery = nil
        galleryArtworks = []
        
        // Generate a new ID
        humanReadableId = HumanReadableID.generate()
        print("Reset gallery and generated new ID: \(humanReadableId)")
    }
    
    var galleryUrl: String {
        return "\(SupabaseConfig.galleryAppDomain)/gallery/\(humanReadableId)"
    }
} 