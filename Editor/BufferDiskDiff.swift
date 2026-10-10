//
//  BufferDiskDiff.swift
//  EditForth
//
//  Line-oriented buffer ↔ disk comparison (CollectionDifference).
//

import Foundation

enum DiffHunkKind: String {
    case insert
    case delete
    case replace
}

struct DiffHunk: Identifiable, Equatable {
    let id: UUID
    let kind: DiffHunkKind
    /// 1-based line in the editor buffer (nil for pure disk-only deletes with no map).
    let bufferLine: Int?
    /// 1-based line on disk (informational).
    let diskLine: Int?
    /// Buffer-side text (insert / replace new line). Empty for pure deletes.
    let bufferSnippet: String
    /// Disk-side text (delete / replace old line). Empty for pure inserts.
    let diskSnippet: String

    /// Preferred one-line preview (buffer when present, else disk).
    var snippet: String {
        bufferSnippet.isEmpty ? diskSnippet : bufferSnippet
    }

    init(
        id: UUID = UUID(),
        kind: DiffHunkKind,
        bufferLine: Int?,
        diskLine: Int?,
        bufferSnippet: String = "",
        diskSnippet: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.bufferLine = bufferLine
        self.diskLine = diskLine
        self.bufferSnippet = bufferSnippet
        self.diskSnippet = diskSnippet
    }
}

struct BufferDiskDiffResult: Equatable {
    let hunks: [DiffHunk]
    let identical: Bool
    let truncated: Bool
    let diskHadCRLF: Bool
    let bufferHadCRLF: Bool
    let diskMissing: Bool
    let errorMessage: String?

    static let maxHunks = 2_000

    static func identicalResult(diskHadCRLF: Bool, bufferHadCRLF: Bool) -> BufferDiskDiffResult {
        BufferDiskDiffResult(
            hunks: [],
            identical: true,
            truncated: false,
            diskHadCRLF: diskHadCRLF,
            bufferHadCRLF: bufferHadCRLF,
            diskMissing: false,
            errorMessage: nil
        )
    }
}

enum BufferDiskDiff {
    /// Split into lines; strip trailing `\r` so CRLF vs LF does not explode the diff.
    static func lines(from text: String) -> (lines: [String], hadCRLF: Bool) {
        var hadCRLF = false
        // Preserve a trailing empty line when the text ends with `\n` (split behavior).
        let raw: [String]
        if text.isEmpty {
            raw = [""]
        } else {
            raw = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        }
        let normalized = raw.map { line -> String in
            if line.hasSuffix("\r") {
                hadCRLF = true
                return String(line.dropLast())
            }
            return line
        }
        return (normalized, hadCRLF)
    }

    static func compare(bufferText: String, diskText: String?) -> BufferDiskDiffResult {
        let buffer = lines(from: bufferText)
        guard let diskText else {
            return BufferDiskDiffResult(
                hunks: [],
                identical: false,
                truncated: false,
                diskHadCRLF: false,
                bufferHadCRLF: buffer.hadCRLF,
                diskMissing: true,
                errorMessage: nil
            )
        }
        let disk = lines(from: diskText)
        if buffer.lines == disk.lines {
            return .identicalResult(diskHadCRLF: disk.hadCRLF, bufferHadCRLF: buffer.hadCRLF)
        }

        let difference = buffer.lines.difference(from: disk.lines)

        // Emit deletes then inserts in difference order. Pair a remove with the
        // next insert only when they share the same offset (in-place replace).
        var hunks: [DiffHunk] = []
        var truncated = false
        var pendingRemove: (offset: Int, element: String)?

        func appendHunk(_ hunk: DiffHunk) {
            guard hunks.count < BufferDiskDiffResult.maxHunks else {
                truncated = true
                return
            }
            hunks.append(hunk)
        }

        func flushRemove() {
            guard let rem = pendingRemove else { return }
            pendingRemove = nil
            appendHunk(
                DiffHunk(
                    kind: .delete,
                    bufferLine: nil,
                    diskLine: rem.offset + 1,
                    bufferSnippet: "",
                    diskSnippet: truncateSnippet(rem.element)
                )
            )
        }

        for change in difference {
            if truncated { break }
            switch change {
            case .remove(let offset, let element, _):
                flushRemove()
                pendingRemove = (offset, element)
            case .insert(let offset, let element, _):
                if let rem = pendingRemove, rem.offset == offset {
                    pendingRemove = nil
                    appendHunk(
                        DiffHunk(
                            kind: .replace,
                            bufferLine: offset + 1,
                            diskLine: rem.offset + 1,
                            bufferSnippet: truncateSnippet(element),
                            diskSnippet: truncateSnippet(rem.element)
                        )
                    )
                } else {
                    flushRemove()
                    appendHunk(
                        DiffHunk(
                            kind: .insert,
                            bufferLine: offset + 1,
                            diskLine: nil,
                            bufferSnippet: truncateSnippet(element),
                            diskSnippet: ""
                        )
                    )
                }
            }
        }
        flushRemove()

        return BufferDiskDiffResult(
            hunks: hunks,
            identical: hunks.isEmpty && !truncated,
            truncated: truncated,
            diskHadCRLF: disk.hadCRLF,
            bufferHadCRLF: buffer.hadCRLF,
            diskMissing: false,
            errorMessage: nil
        )
    }

    private static func truncateSnippet(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let base = trimmed.isEmpty ? line : trimmed
        if base.count <= 120 { return base }
        return String(base.prefix(117)) + "…"
    }

    static func readDisk(url: URL) -> (text: String?, error: String?) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (nil, nil) // missing — caller treats as diskMissing
        }
        do {
            let data = try Data(contentsOf: url)
            if let utf8 = String(data: data, encoding: .utf8) {
                return (utf8, nil)
            }
            if let latin = String(data: data, encoding: .isoLatin1) {
                return (latin, nil)
            }
            return (nil, "Could not decode file as text")
        } catch {
            return (nil, error.localizedDescription)
        }
    }
}
