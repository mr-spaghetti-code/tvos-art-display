# Digital Art Display for Apple TV

A beautiful tvOS application that transforms your Apple TV into a digital art gallery, displaying curated collections of digital artworks and NFTs with elegant transitions and customizable viewing options.

![Digital Art Display](https://img.shields.io/badge/Platform-tvOS%2018.2+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue.svg)
![License](https://img.shields.io/badge/License-Open%20Source-green.svg)

## ✨ Features

### 🎨 Gallery Management
- **QR Code Gallery Creation**: Generate unique gallery IDs with human-readable names
- **Web-based Curation**: Create and manage art collections through a companion web interface
- **Real-time Sync**: Automatically updates when new artworks are added to galleries
- **Persistent Storage**: Remembers your last viewed gallery across app sessions

### 🖼️ Artwork Display
- **High-Quality Rendering**: Optimized image loading and caching for Apple TV displays
- **GIF Animation Support**: Full support for animated artworks with speed controls
- **Artwork Metadata**: Display artist names, descriptions, and collection information
- **Smart Navigation**: Intuitive Apple TV remote controls for browsing collections

### 🎛️ Customization Options
- **Background Themes**: 7 different background colors including smart blur mode
- **Smart Blur**: Dynamic background that blurs the current artwork for an immersive experience
- **Animation Speed Control**: Adjust GIF playback speed from 0.25x to 2x
- **Gallery Thumbnails**: Visual overview of your entire collection

### 📱 User Experience
- **Apple TV Optimized**: Native tvOS interface designed for living room viewing
- **Focus Engine Integration**: Seamless navigation using Apple TV remote
- **Memory Efficient**: Intelligent image caching and cleanup for smooth performance
- **Loading Progress**: Visual feedback during gallery synchronization

## 🏗️ Architecture

### Tech Stack
- **Platform**: tvOS 18.2+
- **Framework**: SwiftUI with UIKit integration
- **Backend**: Supabase (PostgreSQL database)
- **Language**: Swift 5.0
- **Dependencies**: Supabase Swift SDK

### Key Components

```
Digital Art Display/
├── Digital_Art_DisplayApp.swift    # App entry point
├── ContentView.swift               # Main UI controller
├── Models.swift                    # Data models (ArtworkItem, Gallery)
├── GalleryManager.swift           # Gallery state management
├── ImageCache.swift               # Image loading and caching
├── QRCodeGenerator.swift          # QR code generation
├── HumanReadableID.swift          # Gallery ID generation
└── SupabaseConfig.swift           # Backend configuration
```

### Data Models

**ArtworkItem**: Represents individual artworks with metadata including:
- Image URL and metadata (name, description)
- Blockchain information (chain, contract address, token ID)
- Display properties and traits

**Gallery**: Collection container with:
- Unique human-readable ID
- Array of artwork items
- Timestamps and activity status

## 🚀 Getting Started

### Prerequisites
- macOS with Xcode 16.2+
- Apple TV (4th generation or later) or Apple TV Simulator
- Supabase account for backend services

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/tvos-art-display.git
   cd tvos-art-display
   ```

2. **Configure Supabase**
   - Copy `SupabaseConfig.swift.template` to `SupabaseConfig.swift`
   - Update with your Supabase credentials:
   ```swift
   struct SupabaseConfig {
       static let url = URL(string: "YOUR_SUPABASE_URL")!
       static let anonKey = "YOUR_SUPABASE_ANON_KEY"
       static let galleryAppDomain = "YOUR_DOMAIN"
   }
   ```

3. **Set up Supabase Database**
   Create a `galleries` table with the following structure:
   ```sql
   CREATE TABLE galleries (
       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
       human_readable_id TEXT UNIQUE NOT NULL,
       artworks JSONB,
       created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
       updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
       last_accessed_at TIMESTAMP WITH TIME ZONE,
       is_active BOOLEAN DEFAULT true
   );
   ```

4. **Build and Run**
   ```bash
   # Open in Xcode
   open "Digital Art Display.xcodeproj"
   
   # Or build from command line
   xcodebuild -project "Digital Art Display.xcodeproj" -scheme "Digital Art Display"
   ```

## 📖 Usage

### Creating a Gallery

1. **Launch the app** on your Apple TV
2. **Scan the QR code** with your phone or note the Gallery ID
3. **Visit the web interface** using the provided URL
4. **Add artworks** to your gallery through the web interface
5. **Watch automatically** as your Apple TV updates with new content

### Navigation Controls

| Apple TV Remote | Action |
|----------------|---------|
| **Swipe Left/Right** | Navigate between artworks |
| **Swipe Up** | Open gallery thumbnail view |
| **Swipe Down** | Open settings panel |
| **Play/Pause** | Toggle gallery view or generate new ID |
| **Select** | Choose artwork (in gallery view) |
| **Menu** | Close overlays and return to main view |

### Settings Options

- **Background Color**: Choose from 7 preset colors or enable smart blur
- **Smart Blur**: Use current artwork as a blurred background
- **GIF Speed**: Control animation speed for moving artworks
- **Refresh Gallery**: Manually sync with backend
- **Reset Gallery**: Clear current gallery and generate new ID

## 🔧 Development

### Building
```bash
# Debug build
xcodebuild -project "Digital Art Display.xcodeproj" -scheme "Digital Art Display" -configuration Debug

# Release build  
xcodebuild -project "Digital Art Display.xcodeproj" -scheme "Digital Art Display" -configuration Release
```

### Testing
```bash
# Run all tests
xcodebuild test -project "Digital Art Display.xcodeproj" -scheme "Digital Art Display"

# Test with specific simulator
xcodebuild test -project "Digital Art Display.xcodeproj" -scheme "Digital Art Display" -destination 'platform=tvOS Simulator,name=Apple TV'
```

### Project Structure

The app follows standard SwiftUI architecture patterns:

- **State Management**: `@StateObject` and `@ObservableObject` for reactive UI updates
- **Image Loading**: Custom `ImageLoader` with caching and progress tracking
- **Focus Management**: tvOS-specific `@FocusState` for remote navigation
- **Memory Management**: Intelligent cache cleanup for optimal Apple TV performance

## 🎯 Features in Detail

### Smart Image Caching
- **Prioritized Loading**: Loads nearby images first for smooth navigation
- **Memory Optimization**: Automatic cleanup of distant images
- **Progress Tracking**: Visual feedback during batch image loading
- **GIF Support**: Efficient animated image playback with speed controls

### Gallery Synchronization
- **Polling Updates**: Automatically checks for new artworks
- **Human-Readable IDs**: Easy-to-share gallery identifiers (e.g., "happy-golden-sunset")
- **Persistent Sessions**: Remembers and restores previous gallery sessions
- **Real-time Updates**: Seamless integration of new content

### Apple TV Optimization
- **Focus Engine**: Native tvOS navigation patterns
- **Memory Efficiency**: Optimized for Apple TV's limited memory
- **Display Quality**: High-resolution rendering for large displays  
- **Remote Integration**: Full Apple TV remote feature support

## 🤝 Contributing

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Guidelines
- Follow Swift style conventions
- Maintain tvOS compatibility
- Add tests for new features
- Update documentation as needed

## 📄 License

This project is open source and available under the [MIT License](LICENSE.md).

## 🙏 Acknowledgments

- Built with ❤️ using SwiftUI and the Supabase ecosystem
- Designed specifically for the Apple TV viewing experience
- Inspired by the growing digital art and NFT communities

---

**Transform your Apple TV into a personal art gallery. Curate, display, and enjoy digital art in your living room.** 