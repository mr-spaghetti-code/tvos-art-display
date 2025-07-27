//
//  Models.swift
//  Digital Art Display
//
//  Created by Joao Fiadeiro on 7/14/25.
//

import Foundation

// MARK: - Artwork Models

struct ArtworkMetadata: Codable, Equatable {
    let image: String
    let name: String?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case image, name, description
    }
}

struct ArtworkItem: Identifiable, Codable, Equatable {
    let id = UUID()
    let metadata: ArtworkMetadata
    let chain: String
    let contractAddress: String
    let tokenId: String
    let groupId: String?  // New field for grouping artworks
    
    var url: String {
        return metadata.image
    }
    
    enum CodingKeys: String, CodingKey {
        case metadata, chain, contractAddress, tokenId, groupId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metadata = try container.decode(ArtworkMetadata.self, forKey: .metadata)
        chain = try container.decode(String.self, forKey: .chain)
        contractAddress = try container.decode(String.self, forKey: .contractAddress)
        tokenId = try container.decode(String.self, forKey: .tokenId)
        groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(chain, forKey: .chain)
        try container.encode(contractAddress, forKey: .contractAddress)
        try container.encode(tokenId, forKey: .tokenId)
        try container.encodeIfPresent(groupId, forKey: .groupId)
    }
    
    // Equatable implementation - compare based on content, not id
    static func == (lhs: ArtworkItem, rhs: ArtworkItem) -> Bool {
        return lhs.metadata == rhs.metadata &&
               lhs.chain == rhs.chain &&
               lhs.contractAddress == rhs.contractAddress &&
               lhs.tokenId == rhs.tokenId &&
               lhs.groupId == rhs.groupId
    }
}

// MARK: - Display Item Types

enum DisplayItem: Identifiable {
    case single(ArtworkItem)
    case group([ArtworkItem])
    
    var id: String {
        switch self {
        case .single(let artwork):
            return artwork.id.uuidString
        case .group(let artworks):
            return artworks.first?.groupId ?? UUID().uuidString
        }
    }
    
    var artworks: [ArtworkItem] {
        switch self {
        case .single(let artwork):
            return [artwork]
        case .group(let artworks):
            return artworks
        }
    }
    
    // Get the primary artwork for display purposes
    var primaryArtwork: ArtworkItem? {
        switch self {
        case .single(let artwork):
            return artwork
        case .group(let artworks):
            return artworks.first
        }
    }
}

// MARK: - Gallery Models

struct Gallery: Codable {
    let id: UUID
    let humanReadableId: String
    let artworks: [ArtworkItem]?
    let createdAt: Date
    let updatedAt: Date
    let lastAccessedAt: Date?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case humanReadableId = "human_readable_id"
        case artworks
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastAccessedAt = "last_accessed_at"
        case isActive = "is_active"
    }
} 