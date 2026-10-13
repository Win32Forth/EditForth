//
//  ForthAgentRunner.swift
//  EditForth
//
//  Headless 64Forth --agent eval for Ask Forth. Separate process from the
//  live companion console (see Agent-channel.md).
//

import Foundation

struct ForthAgentResult: Sendable {
    var exitCode: Int32
    var transcript: String
    var binaryPath: String
    var workingDirectory: String
}

enum ForthAgentError: LocalizedError {
    case binaryNotFound
    case emptySource
    case launchFailed(String)
    case timedOut(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Could not find EditForth’s 64Forth.app binary for --agent. Build the Debug companion first."
        case .emptySource:
            return "Nothing to evaluate."
        case .launchFailed(let detail):
            return "Failed to launch 64Forth --agent (\(detail))."
        case .timedOut(let seconds):
            return "Agent eval timed out after \(Int(seconds))s."
        }
    }
}

enum ForthAgentRunner {
    /// Default timeout for short Ask Forth evals.
    nonisolated static let defaultTimeout: TimeInterval = 45

    /// Pull Forth source out of a model reply (fenced block preferred).
    nonisolated static func extractForthSource(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // ```forth … ``` or ``` … ```
        if let fence = firstFencedBlock(in: trimmed) {
            return fence.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    /// Run source via `--agent`. Multi-line → temp `.fth` + `-f`; single line → `-e`.
    nonisolated static func evaluate(
        source: String,
        cwd: URL?,
        autoload: Bool,
        timeout: TimeInterval = ForthAgentRunner.defaultTimeout
    ) async throws -> ForthAgentResult {
        let code = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { throw ForthAgentError.emptySource }
        guard let exe = SixtyFourForthLocator.locateBinary() else {
            throw ForthAgentError.binaryNotFound
        }

        let workDir = cwd ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/EditForth", isDirectory: true)

        var args = ["--agent"]
        args.append(autoload ? "--autoload" : "--no-autoload")
        args.append(contentsOf: ["-c", workDir.path])

        var tempFile: URL?
        defer {
            if let tempFile {
                try? FileManager.default.removeItem(at: tempFile)
            }
        }

        let nonEmptyLines = code
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if nonEmptyLines.count <= 1, !code.contains("\n") || nonEmptyLines.count == 1 {
            let line = nonEmptyLines.first ?? code
            args.append(contentsOf: ["-e", line])
        } else {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("editforth-ask-\(UUID().uuidString).fth")
            try code.write(to: url, atomically: true, encoding: .utf8)
            tempFile = url
            args.append(contentsOf: ["-f", url.path])
        }

        return try await runProcess(
            executable: exe,
            arguments: args,
            workingDirectory: workDir.path,
            timeout: timeout
        )
    }

    // MARK: - Private

    nonisolated private static func firstFencedBlock(in text: String) -> String? {
        guard let start = text.range(of: "```") else { return nil }
        var after = text[start.upperBound...]
        // Optional language tag on the opening fence line.
        if let nl = after.firstIndex(of: "\n") {
            after = after[after.index(after: nl)...]
        } else {
            return nil
        }
        guard let end = after.range(of: "```") else { return nil }
        return String(after[..<end.lowerBound])
    }

    nonisolated private static func runProcess(
        executable: URL,
        arguments: [String],
        workingDirectory: String,
        timeout: TimeInterval
    ) async throws -> ForthAgentResult {
        try await withCheckedThrowingContinuation { continuation in
            let proc = Process()
            proc.executableURL = executable
            proc.arguments = arguments
            proc.standardInput = FileHandle.nullDevice

            let outPipe = Pipe()
            let errPipe = Pipe()
            proc.standardOutput = outPipe
            proc.standardError = errPipe

            final class ResumeOnce: @unchecked Sendable {
                private let lock = NSLock()
                private var resumed = false
                private let continuation: CheckedContinuation<ForthAgentResult, Error>
                init(_ continuation: CheckedContinuation<ForthAgentResult, Error>) {
                    self.continuation = continuation
                }
                func finish(_ result: Result<ForthAgentResult, Error>) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(with: result)
                }
            }
            let gate = ResumeOnce(continuation)

            do {
                try proc.run()
            } catch {
                gate.finish(.failure(ForthAgentError.launchFailed(error.localizedDescription)))
                return
            }

            let timeoutItem = DispatchWorkItem {
                if proc.isRunning {
                    proc.terminate()
                }
                gate.finish(.failure(ForthAgentError.timedOut(timeout)))
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            proc.terminationHandler = { p in
                timeoutItem.cancel()
                let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                var transcript = out
                if !err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !transcript.isEmpty && !transcript.hasSuffix("\n") { transcript += "\n" }
                    transcript += err
                }
                let result = ForthAgentResult(
                    exitCode: p.terminationStatus,
                    transcript: transcript.trimmingCharacters(in: .whitespacesAndNewlines),
                    binaryPath: executable.path,
                    workingDirectory: workingDirectory
                )
                gate.finish(.success(result))
            }
        }
    }
}
