//
//  ForthLibraryRAGSettings.swift
//  EditForth
//
//  Persisted Library RAG limits and search folder for Ask Forth.
//

import Foundation
import AppKit

/// How Ask Forth picks Library excerpts.
enum ForthLibraryRetrieveMode: String, CaseIterable, Codable, Sendable {
    /// Token hit scoring only (original behavior).
    case keyword
    /// nomic-embed-text cosine search over the on-disk index.
    case semantic
    /// Blend embedding similarity with keyword scores (default).
    case hybrid

    var displayName: String {
        switch self {
        case .keyword: return "Keyword"
        case .semantic: return "Semantic"
        case .hybrid: return "Hybrid"
        }
    }

    var statusLabel: String {
        switch self {
        case .keyword: return "keyword"
        case .semantic: return "embed"
        case .hybrid: return "hybrid"
        }
    }
}

struct ForthLibraryRAGSettings: Equatable, Sendable {
    static let folderKey = "aiAssistantLibraryFolder"
    static let maxSnippetsKey = "aiAssistantLibraryMaxSnippets"
    static let contextLinesKey = "aiAssistantLibraryContextLines"
    static let maxCharsKey = "aiAssistantLibraryMaxChars"
    static let retrieveModeKey = "aiAssistantLibraryRetrieveMode"

    /// Default search root: Sample (clocks, GRAPHICS demos). Library… can point elsewhere.
    static var defaultFolderPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/EditForth/Library/Sample", isDirectory: true)
            .path
    }

    var folderPath: String
    var maxSnippets: Int
    var contextLines: Int
    var maxChars: Int
    var retrieveMode: ForthLibraryRetrieveMode

    static func load() -> ForthLibraryRAGSettings {
        let d = UserDefaults.standard
        let folder = d.string(forKey: folderKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let snippets = d.object(forKey: maxSnippetsKey) as? Int
        let lines = d.object(forKey: contextLinesKey) as? Int
        let chars = d.object(forKey: maxCharsKey) as? Int
        let modeRaw = d.string(forKey: retrieveModeKey)
        let mode = modeRaw.flatMap(ForthLibraryRetrieveMode.init(rawValue:)) ?? .hybrid
        return ForthLibraryRAGSettings(
            folderPath: (folder?.isEmpty == false) ? folder! : defaultFolderPath,
            maxSnippets: clamp(snippets ?? 12, min: 1, max: 40),
            contextLines: clamp(lines ?? 12, min: 2, max: 40),
            maxChars: clamp(chars ?? 16_000, min: 2_000, max: 64_000),
            retrieveMode: mode
        )
    }

    func save() {
        let d = UserDefaults.standard
        d.set(folderPath, forKey: Self.folderKey)
        d.set(maxSnippets, forKey: Self.maxSnippetsKey)
        d.set(contextLines, forKey: Self.contextLinesKey)
        d.set(maxChars, forKey: Self.maxCharsKey)
        d.set(retrieveMode.rawValue, forKey: Self.retrieveModeKey)
    }

    var folderURL: URL {
        URL(fileURLWithPath: folderPath, isDirectory: true)
    }

    private static func clamp(_ v: Int, min: Int, max: Int) -> Int {
        Swift.min(Swift.max(v, min), max)
    }
}
