//
//  FolderSearch.swift
//  EditForth
//
//  Recursive folder search for Global Search v1 (literal substring).
//

import Foundation

struct SearchHit: Identifiable, Hashable {
    let id: UUID
    let fileURL: URL
    let line: Int
    let column: Int
    let snippet: String

    init(fileURL: URL, line: Int, column: Int, snippet: String) {
        self.id = UUID()
        self.fileURL = fileURL
        self.line = line
        self.column = column
        self.snippet = snippet
    }
}

enum FolderSearch {
    static let defaultExtensions = ["fth", "fs", "4th", "f", "txt"]
    static let maxHits = 5_000

    private static let skipDirNames: Set<String> = [
        ".git", ".svn", "DerivedData", "node_modules", ".build", "xcuserdata"
    ]

    struct Request {
        var roots: [URL]
        var extensions: [String]
        var query: String
        var caseSensitive: Bool
        /// Require word boundaries around the match (alnum / `_`).
        var wholeWord: Bool
        /// When false, only files directly in each root folder (no subfolders).
        var recursive: Bool
    }

    struct Result {
        var hits: [SearchHit]
        var truncated: Bool
        var filesScanned: Int
    }

    /// Background-safe scan. Call `isCancelled` often; returns partial hits if cancelled.
    static func run(_ request: Request, isCancelled: () -> Bool = { false }) -> Result {
        let needle = request.query
        guard !needle.isEmpty else {
            return Result(hits: [], truncated: false, filesScanned: 0)
        }
        let exts = Set(
            request.extensions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
                .filter { !$0.isEmpty }
        )
        var hits: [SearchHit] = []
        var truncated = false
        var filesScanned = 0
        let fm = FileManager.default
        let options: String.CompareOptions = request.caseSensitive ? [] : [.caseInsensitive]

        for root in request.roots {
            guard !isCancelled() else { break }
            let rootURL = root.standardizedFileURL
            if request.recursive {
                guard let enumerator = fm.enumerator(
                    at: rootURL,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                while let item = enumerator.nextObject() as? URL {
                    if isCancelled() || truncated { break }
                    let name = item.lastPathComponent
                    if skipDirNames.contains(name) {
                        enumerator.skipDescendants()
                        continue
                    }
                    // Skip .app bundles (and similar) entirely.
                    if name.hasSuffix(".app") || name.hasSuffix(".framework") || name.hasSuffix(".xcarchive") {
                        enumerator.skipDescendants()
                        continue
                    }
                    considerFile(
                        item,
                        exts: exts,
                        needle: needle,
                        options: options,
                        wholeWord: request.wholeWord,
                        hits: &hits,
                        truncated: &truncated,
                        filesScanned: &filesScanned
                    )
                }
            } else {
                // Folder level only — files directly in each root.
                let items = (try? fm.contentsOfDirectory(
                    at: rootURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
                for item in items {
                    if isCancelled() || truncated { break }
                    considerFile(
                        item,
                        exts: exts,
                        needle: needle,
                        options: options,
                        wholeWord: request.wholeWord,
                        hits: &hits,
                        truncated: &truncated,
                        filesScanned: &filesScanned
                    )
                }
            }
            if truncated { break }
        }

        return Result(hits: hits, truncated: truncated, filesScanned: filesScanned)
    }

    private static func considerFile(
        _ item: URL,
        exts: Set<String>,
        needle: String,
        options: String.CompareOptions,
        wholeWord: Bool,
        hits: inout [SearchHit],
        truncated: inout Bool,
        filesScanned: inout Int
    ) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), !isDir.boolValue else {
            return
        }
        let name = item.lastPathComponent
        let ext = item.pathExtension.lowercased()
        if !exts.isEmpty && !exts.contains(ext) { return }
        if name == "HYPER.NDX" { return }

        filesScanned += 1
        guard let data = try? Data(contentsOf: item), !data.isEmpty else { return }
        if data.contains(0) { return }
        let text = String(decoding: data, as: UTF8.self)
        scanFile(
            text: text,
            fileURL: item.standardizedFileURL,
            needle: needle,
            options: options,
            wholeWord: wholeWord,
            hits: &hits,
            truncated: &truncated
        )
    }

    /// Forth-ish name characters so Whole Word treats CLOCK-BOX as one word.
    private static let wordChars = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "_-?!'.+*/<>=@$")
    )

    private static func isWordChar(_ ch: Character) -> Bool {
        ch.unicodeScalars.allSatisfy { wordChars.contains($0) }
    }

    /// True when `range` in `line` is a whole-word hit.
    private static func isWholeWordMatch(in line: String, range: Range<String.Index>) -> Bool {
        if range.lowerBound > line.startIndex {
            let before = line[line.index(before: range.lowerBound)]
            if isWordChar(before) { return false }
        }
        if range.upperBound < line.endIndex {
            let after = line[range.upperBound]
            if isWordChar(after) { return false }
        }
        return true
    }

    private static func scanFile(
        text: String,
        fileURL: URL,
        needle: String,
        options: String.CompareOptions,
        wholeWord: Bool,
        hits: inout [SearchHit],
        truncated: inout Bool
    ) {
        // IMPORTANT: walk Unicode scalars, not Characters. In Swift, CRLF is one
        // Character (`\r\n`), so `firstIndex(of: "\n")` / `ch == "\n"` miss those
        // breaks and under-count vs NSTextView (Sample/CLOCK.fth: ~35 vs 225).
        var lineNo = 1
        var lineStart = text.unicodeScalars.startIndex
        var i = text.unicodeScalars.startIndex
        let scalars = text.unicodeScalars
        let end = scalars.endIndex
        while i < end {
            if truncated { return }
            let s = scalars[i]
            let next = scalars.index(after: i)
            let isCR = s == "\r"
            let isLF = s == "\n"
            let isOtherSep = s == "\u{2028}" || s == "\u{2029}" || s == "\u{0085}"
            if isCR || isLF || isOtherSep {
                let line = String(String.UnicodeScalarView(scalars[lineStart..<i]))
                scanLine(
                    line,
                    lineNo: lineNo,
                    fileURL: fileURL,
                    needle: needle,
                    options: options,
                    wholeWord: wholeWord,
                    hits: &hits,
                    truncated: &truncated
                )
                if truncated { return }
                // CRLF: consume LF after CR as the same break.
                if isCR && next < end && scalars[next] == "\n" {
                    i = scalars.index(after: next)
                } else {
                    i = next
                }
                lineStart = i
                lineNo += 1
                continue
            }
            i = next
        }
        // Final line when the file has no trailing newline.
        if lineStart < end && !truncated {
            let line = String(String.UnicodeScalarView(scalars[lineStart..<end]))
            scanLine(
                line,
                lineNo: lineNo,
                fileURL: fileURL,
                needle: needle,
                options: options,
                wholeWord: wholeWord,
                hits: &hits,
                truncated: &truncated
            )
        }
    }

    private static func scanLine(
        _ line: String,
        lineNo: Int,
        fileURL: URL,
        needle: String,
        options: String.CompareOptions,
        wholeWord: Bool,
        hits: inout [SearchHit],
        truncated: inout Bool
    ) {
        var searchFrom = line.startIndex
        while let range = line.range(of: needle, options: options, range: searchFrom..<line.endIndex) {
            searchFrom = range.upperBound
            if wholeWord && !isWholeWordMatch(in: line, range: range) {
                continue
            }
            let col = line.distance(from: line.startIndex, to: range.lowerBound) + 1
            let snippet = line.trimmingCharacters(in: .whitespaces)
            hits.append(SearchHit(fileURL: fileURL, line: lineNo, column: col, snippet: snippet))
            if hits.count >= maxHits {
                truncated = true
                return
            }
        }
    }
}
