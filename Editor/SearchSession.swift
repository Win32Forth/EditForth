//
//  SearchSession.swift
//  EditForth
//
//  Special workspace tab: folder-search hit list (not a file buffer).
//

import Foundation
import Combine

final class SearchSession: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String
    @Published var query: String
    @Published var hits: [SearchHit] = []
    @Published var status: String = "Searching…"
    @Published var isSearching: Bool = false

    var roots: [URL]
    var extensions: [String]
    var caseSensitive: Bool
    var wholeWord: Bool
    var recursive: Bool

    private var cancelFlag = false
    private let lock = NSLock()

    init(
        query: String,
        roots: [URL],
        extensions: [String],
        caseSensitive: Bool = false,
        wholeWord: Bool = false,
        recursive: Bool = true
    ) {
        self.query = query
        self.roots = roots
        self.extensions = extensions
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.recursive = recursive
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = q.isEmpty ? "Search" : "Search: \(q)"
    }

    func requestCancel() {
        lock.lock()
        cancelFlag = true
        lock.unlock()
    }

    private func isCancelled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelFlag
    }

    /// Start or restart the scan on a background queue; updates publish on main.
    func start() {
        requestCancel()
        lock.lock()
        cancelFlag = false
        lock.unlock()

        let request = FolderSearch.Request(
            roots: roots,
            extensions: extensions,
            query: query,
            caseSensitive: caseSensitive,
            wholeWord: wholeWord,
            recursive: recursive
        )
        DispatchQueue.main.async { [weak self] in
            self?.isSearching = true
            self?.hits = []
            self?.status = "Searching…"
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = FolderSearch.run(request) { self.isCancelled() }
            DispatchQueue.main.async {
                self.isSearching = false
                self.hits = result.hits
                if self.isCancelled() && result.hits.isEmpty {
                    self.status = "Cancelled"
                } else if result.truncated {
                    self.status = "\(result.hits.count) hits (truncated at \(FolderSearch.maxHits)) · \(result.filesScanned) files"
                } else {
                    self.status = "\(result.hits.count) hit\(result.hits.count == 1 ? "" : "s") · \(result.filesScanned) files"
                }
            }
        }
    }
}
