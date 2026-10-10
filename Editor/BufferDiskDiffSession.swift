//
//  BufferDiskDiffSession.swift
//  EditForth
//
//  Special workspace tab: buffer ↔ disk hunk list (not a file buffer).
//

import Foundation
import Combine

final class BufferDiskDiffSession: Identifiable, ObservableObject {
    let id = UUID()
    let sourceTabID: UUID
    let fileURL: URL

    @Published var title: String
    @Published var status: String = "Comparing…"
    @Published var hunks: [DiffHunk] = []
    @Published var isIdentical: Bool = false
    @Published var isComparing: Bool = false
    @Published var canRevert: Bool = false

    private var generation: UInt = 0
    private weak var workspace: WorkspaceModel?

    init(sourceTabID: UUID, fileURL: URL, workspace: WorkspaceModel) {
        self.sourceTabID = sourceTabID
        self.fileURL = fileURL.standardizedFileURL
        self.workspace = workspace
        self.title = "Diff: \(fileURL.lastPathComponent)"
    }

    /// Re-read disk and current buffer text, then recompute hunks.
    func reload() {
        generation &+= 1
        let gen = generation
        let url = fileURL
        let bufferText: String
        if let tab = workspace?.tabs.first(where: { $0.id == sourceTabID }) {
            bufferText = tab.text
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isComparing = false
                self?.hunks = []
                self?.isIdentical = false
                self?.canRevert = false
                self?.status = "Source tab closed"
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.isComparing = true
            self?.status = "Comparing…"
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let disk = BufferDiskDiff.readDisk(url: url)
            let result: BufferDiskDiffResult
            if let err = disk.error {
                result = BufferDiskDiffResult(
                    hunks: [],
                    identical: false,
                    truncated: false,
                    diskHadCRLF: false,
                    bufferHadCRLF: false,
                    diskMissing: false,
                    errorMessage: err
                )
            } else {
                result = BufferDiskDiff.compare(bufferText: bufferText, diskText: disk.text)
            }

            DispatchQueue.main.async {
                guard let self, self.generation == gen else { return }
                self.apply(result)
            }
        }
    }

    private func apply(_ result: BufferDiskDiffResult) {
        isComparing = false
        hunks = result.hunks
        isIdentical = result.identical
        canRevert = !result.identical && !result.diskMissing && result.errorMessage == nil

        if let err = result.errorMessage {
            status = "Error: \(err)"
            return
        }
        if result.diskMissing {
            status = "Disk file missing"
            return
        }
        if result.identical {
            var s = "Identical"
            if result.diskHadCRLF != result.bufferHadCRLF {
                if result.diskHadCRLF {
                    s += " · CRLF on disk normalized"
                } else if result.bufferHadCRLF {
                    s += " · CRLF in buffer normalized"
                }
            }
            status = s
            return
        }

        var parts: [String] = ["\(result.hunks.count) hunk\(result.hunks.count == 1 ? "" : "s")"]
        if result.truncated {
            parts.append("truncated at \(BufferDiskDiffResult.maxHunks)")
        }
        if let tab = workspace?.tabs.first(where: { $0.id == sourceTabID }), tab.isDirty {
            parts.append("buffer dirty")
        }
        if result.diskHadCRLF != result.bufferHadCRLF {
            parts.append(result.diskHadCRLF ? "CRLF on disk" : "CRLF in buffer")
        }
        status = parts.joined(separator: " · ")
    }
}
