//
//  HyperReindex.swift
//  64Forth
//
//  HYPER-REINDEX stays the Forth scanner (HX-BUILD-INDEX). This host starts
//  that scan in a second 64Forth process so the live Config/HYPER.NDX is not
//  truncated and, in the editor companion, the kernel is not held for the scan.
//  The side file is renamed over the live index only after the child exits 0.
//

import Foundation

@_cdecl("host_hyper_reindex")
public func host_hyper_reindex() -> Int64 {
    if ProcessInfo.processInfo.environment["HYPER_REINDEX_CHILD"] == "1" {
        return 0
    }
    return HyperReindexHost.shared.run()
}

final class HyperReindexHost {
    static let shared = HyperReindexHost()

    private let stateLock = NSLock()
    private var busy = false
    private var child: Process?

    private init() {}

    /// Called on the kernel thread from `(HX-BG-REINDEX)`.
    /// 1 = the new index is in place; Forth should HYPER-LOAD before returning.
    /// 0 = nothing for this call to reload (skipped, failed, or still running).
    func run() -> Int64 {
        let plan = HyperIndexPlan.make()
        if plan.sources.isEmpty {
            emit("HYPER-REINDEX: no source files\n")
            return 0
        }
        if !plan.needsRebuild {
            emit("HYPER-REINDEX: up to date\n")
            return 0
        }
        if !begin() {
            emit("HYPER-REINDEX: already indexing\n")
            return 0
        }

        let waitForFile = !CompanionChannel.isRequested
        if waitForFile {
            emit("HYPER-REINDEX: indexing\n")
        } else {
            emit("HYPER-REINDEX: indexing in the background\n")
        }

        let launched: Process
        do {
            launched = try Self.launch(building: plan.buildingURL)
        } catch {
            end()
            emit("HYPER-REINDEX: failed (\(error.localizedDescription))\n")
            return 0
        }
        stateLock.lock()
        child = launched
        stateLock.unlock()

        if waitForFile {
            launched.waitUntilExit()
            let output = Self.output(of: launched)
            let ok = finish(
                status: launched.terminationStatus,
                output: output,
                plan: plan
            )
            end()
            return ok ? 1 : 0
        }

        launched.terminationHandler = { [weak self] process in
            let output = Self.output(of: process)
            let status = process.terminationStatus
            DispatchQueue.global(qos: .utility).async {
                guard let self else { return }
                if self.finish(status: status, output: output, plan: plan) {
                    KernelBridge.shared.evaluateHyperReload()
                }
                self.end()
            }
        }
        return 0
    }

    /// Swap the side file into place. Prints the entry count on success.
    private func finish(status: Int32, output: String, plan: HyperIndexPlan) -> Bool {
        let fm = FileManager.default
        let built = status == 0 && output.contains("HX-BUILD-OK")
            && fm.fileExists(atPath: plan.buildingURL.path)
        guard built else {
            try? fm.removeItem(at: plan.buildingURL)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = status == 0 ? "side file was not written" : "child exited \(status)"
            let detail = trimmed.isEmpty
                ? fallback
                : (trimmed.count > 500 ? String(trimmed.suffix(500)) : trimmed)
            emitResult("HYPER-REINDEX: failed (\(detail))\n")
            return false
        }
        let entries = Self.entryCount(at: plan.buildingURL)
        guard Self.swapIntoPlace(temp: plan.buildingURL, index: plan.destURL) else {
            emitResult("HYPER-REINDEX: failed (could not replace Config/HYPER.NDX)\n")
            return false
        }
        emitResult("HYPER-REINDEX: \(entries) entries, switched in Config/HYPER.NDX\n")
        return true
    }

    private func emit(_ text: String) {
        KernelBridge.shared.emitHostNote(text)
    }

    /// Companion results arrive after `ok(n)>`. Show them on the editor status
    /// strip so they do not insert into the console input line. Standalone still
    /// prints before HYPER-REINDEX returns.
    private func emitResult(_ text: String) {
        if CompanionChannel.isRequested {
            let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
            ForthEditorServer.shared.broadcast(.statusNote(text: line))
        } else {
            emit(text)
        }
    }

    private func begin() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        if busy { return false }
        busy = true
        return true
    }

    private func end() {
        stateLock.lock()
        child = nil
        busy = false
        stateLock.unlock()
    }

    private static func launch(building: URL) throws -> Process {
        guard let exe = Bundle.main.executableURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        if building.path.contains("\"") || building.path.contains("\n") {
            throw CocoaError(.fileWriteUnknown)
        }
        // kernel_eval keeps only 1023 characters. A long absolute path on the
        // same line as the load was cut off before HX-BUILD-INDEX.
        let pathFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("editforth-hyper-path.txt")
        try Data((building.path + "\n").utf8).write(to: pathFile, options: .atomic)
        let load =
            "ONLY FORTH DEFINITIONS VOCABULARY HYPER-VOC "
            + "ONLY FORTH ALSO HYPER-VOC DEFINITIONS "
            + "S\" Library/Hyper/hyper-index.fth\" INCLUDED"
        let build = "S\" \(pathFile.path)\" HX-SET-OUT-FILE MIN-HYPER-NOISE ON HX-BUILD-INDEX"
        let capture = PipeCapture()
        let process = Process()
        process.executableURL = exe
        process.arguments = ["--agent", "--no-autoload", "-e", load, "-e", build]
        var env = ProcessInfo.processInfo.environment
        env["HYPER_REINDEX_CHILD"] = "1"
        process.environment = env
        process.standardOutput = capture.pipe
        process.standardError = capture.pipe
        process.qualityOfService = .utility
        let cwd = FileHost.shared.logicalCurrentDirectory
        if !cwd.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd, isDirectory: true)
        }
        process.standardInput = FileHandle.nullDevice
        objc_setAssociatedObject(process, &pipeKey, capture, .OBJC_ASSOCIATION_RETAIN)
        try process.run()
        return process
    }

    private static func output(of process: Process) -> String {
        guard let capture = objc_getAssociatedObject(process, &pipeKey) as? PipeCapture else {
            return ""
        }
        return capture.text()
    }

    private static func swapIntoPlace(temp: URL, index: URL) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(
                at: index.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fm.fileExists(atPath: index.path) {
                _ = try fm.replaceItemAt(index, withItemAt: temp)
            } else {
                try fm.moveItem(at: temp, to: index)
            }
            return true
        } catch {
            try? fm.removeItem(at: temp)
            return false
        }
    }

    private static func entryCount(at url: URL) -> Int {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        var n = 0
        for line in text.split(whereSeparator: \.isNewline) {
            guard let first = line.first, first != "#", first != "@" else { continue }
            n += 1
        }
        return n
    }
}

private var pipeKey: UInt8 = 0

/// Drains a process pipe while the child runs, so a full pipe cannot stall it.
private final class PipeCapture {
    let pipe = Pipe()
    private let lock = NSLock()
    private var data = Data()
    private let done = DispatchSemaphore(value: 0)
    private var finished = false

    init() {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                self.finish()
                return
            }
            self.lock.lock()
            self.data.append(chunk)
            self.lock.unlock()
        }
    }

    func text() -> String {
        done.wait()
        lock.lock()
        let copy = data
        lock.unlock()
        return String(data: copy, encoding: .utf8) ?? ""
    }

    private func finish() {
        lock.lock()
        let already = finished
        finished = true
        lock.unlock()
        if !already { done.signal() }
    }
}

private struct HyperSourceFile {
    var path: String
    var modified: Date
}

private struct HyperIndexPlan {
    var destURL: URL
    var buildingURL: URL
    var sources: [HyperSourceFile]
    var needsRebuild: Bool

    static func make() -> HyperIndexPlan {
        let fm = FileManager.default
        let opened = FileAccess.shared.resolvePath("Config/HYPER.NDX")
        let dest = FileAccess.shared.writableURL(for: opened)
        let building = dest.deletingLastPathComponent()
            .appendingPathComponent("HYPER.NDX.building")
        let live = fm.fileExists(atPath: opened.path) ? opened : dest
        var sources: [HyperSourceFile] = []
        for path in FileHost.shared.buildHyperSourceList() {
            let url = FileAccess.shared.resolvePath(path)
            guard fm.fileExists(atPath: url.path) else { continue }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            sources.append(HyperSourceFile(path: path, modified: modified))
        }
        let cfgURL = FileAccess.shared.resolvePath("Config/HYPER.CFG")
        let cfgModified = fm.fileExists(atPath: cfgURL.path)
            ? (try? cfgURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            : nil
        let needs = needsRebuild(
            indexURL: live,
            cfgModified: cfgModified,
            sources: sources
        )
        return HyperIndexPlan(
            destURL: dest,
            buildingURL: building,
            sources: sources,
            needsRebuild: needs
        )
    }

    private static func needsRebuild(
        indexURL: URL,
        cfgModified: Date?,
        sources: [HyperSourceFile]
    ) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: indexURL.path) else { return true }
        guard let values = try? indexURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let indexDate = values.contentModificationDate,
              (values.fileSize ?? 0) > 0 else {
            return true
        }
        if let cfgModified, cfgModified > indexDate { return true }
        if sources.contains(where: { $0.modified > indexDate }) { return true }
        let indexed = sectionPaths(indexURL)
        if Set(indexed) != Set(sources.map(\.path)) { return true }
        return false
    }

    private static func sectionPaths(_ indexURL: URL) -> [String] {
        guard let text = try? String(contentsOf: indexURL, encoding: .utf8) else { return [] }
        var paths: [String] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            guard raw.hasPrefix("@ ") else { continue }
            let path = String(raw.dropFirst(2))
            if !path.isEmpty { paths.append(path) }
        }
        return paths
    }
}
