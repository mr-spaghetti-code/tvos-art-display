//
//  HumanReadableID.swift
//  Digital Art Display
//
//  Created by Joao Fiadeiro on 7/14/25.
//

import Foundation

struct HumanReadableID {
    private static let adjectives = [
        "happy", "bright", "calm", "gentle", "quiet", "warm", "cool", "fresh",
        "swift", "bold", "noble", "wise", "kind", "brave", "clever", "eager",
        "fancy", "jolly", "lovely", "merry", "proud", "quick", "sharp", "smart"
    ]
    
    private static let colors = [
        "blue", "green", "golden", "silver", "purple", "amber", "coral", "crystal",
        "ruby", "jade", "pearl", "bronze", "copper", "ivory", "ebony", "azure",
        "crimson", "emerald", "indigo", "magenta", "olive", "rose", "teal", "violet"
    ]
    
    private static let nouns = [
        "sunset", "ocean", "mountain", "forest", "river", "cloud", "star", "moon",
        "garden", "meadow", "valley", "canyon", "desert", "island", "lake", "beach",
        "aurora", "cascade", "dawn", "horizon", "lighthouse", "pathway", "rainbow", "sanctuary"
    ]
    
    static func generate() -> String {
        let adjective = adjectives.randomElement()!
        let color = colors.randomElement()!
        let noun = nouns.randomElement()!
        
        return "\(adjective)-\(color)-\(noun)"
    }
} 