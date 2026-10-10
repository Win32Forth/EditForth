//
//  BufferDiskDiffView.swift
//  EditForth
//
//  Colored unified-diff hunk list. Click jumps into the buffer.
//

import SwiftUI
import AppKit

struct BufferDiskDiffView: View {
    @ObservedObject var session: BufferDiskDiffSession
    @ObservedObject var workspace: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(session.status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                legend
                if session.isComparing {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Reload Diff") {
                    session.reload()
                }
                .controlSize(.small)
                .disabled(session.isComparing)

                Button("Revert to Disk…") {
                    workspace.revertDiffToDisk(session)
                }
                .controlSize(.small)
                .disabled(session.isComparing || !session.canRevert)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if session.hunks.isEmpty && !session.isComparing {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(session.hunks) { hunk in
                            Button {
                                open(hunk)
                            } label: {
                                DiffHunkBlock(hunk: hunk)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 10) {
            LegendSwatch(color: DiffColors.deleteFill, label: "disk only")
            LegendSwatch(color: DiffColors.insertFill, label: "buffer only")
            LegendSwatch(color: DiffColors.replaceFill, label: "changed")
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }

    private var emptyMessage: String {
        if session.isIdentical { return "Buffer matches disk" }
        if session.status.hasPrefix("Error") { return session.status }
        if session.status == "Disk file missing" { return "File is missing on disk" }
        if session.status == "Source tab closed" { return "Source tab closed" }
        return "No hunks"
    }

    private func open(_ hunk: DiffHunk) {
        workspace.focusDiffHunk(session, hunk: hunk)
    }
}

// MARK: - Row block

private struct DiffHunkBlock: View {
    let hunk: DiffHunk

    var body: some View {
        VStack(spacing: 0) {
            switch hunk.kind {
            case .delete:
                DiffLineRow(
                    marker: "−",
                    lineLabel: diskLineLabel,
                    text: display(hunk.diskSnippet),
                    fill: DiffColors.deleteFill,
                    markerColor: DiffColors.deleteMarker,
                    strikethrough: true
                )
            case .insert:
                DiffLineRow(
                    marker: "+",
                    lineLabel: bufferLineLabel,
                    text: display(hunk.bufferSnippet),
                    fill: DiffColors.insertFill,
                    markerColor: DiffColors.insertMarker,
                    strikethrough: false
                )
            case .replace:
                DiffLineRow(
                    marker: "−",
                    lineLabel: diskLineLabel,
                    text: display(hunk.diskSnippet),
                    fill: DiffColors.deleteFill,
                    markerColor: DiffColors.deleteMarker,
                    strikethrough: true
                )
                DiffLineRow(
                    marker: "+",
                    lineLabel: bufferLineLabel,
                    text: display(hunk.bufferSnippet),
                    fill: DiffColors.insertFill,
                    markerColor: DiffColors.insertMarker,
                    strikethrough: false
                )
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.35))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
    }

    private var bufferLineLabel: String {
        if let b = hunk.bufferLine { return String(format: "%4d", b) }
        return "    "
    }

    private var diskLineLabel: String {
        if let d = hunk.diskLine { return String(format: "%4d", d) }
        return "    "
    }

    private func display(_ s: String) -> String {
        s.isEmpty ? " " : s
    }
}

private struct DiffLineRow: View {
    let marker: String
    let lineLabel: String
    let text: String
    let fill: Color
    let markerColor: Color
    let strikethrough: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(marker)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(markerColor)
                .frame(width: 18, alignment: .center)
            Text(lineLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .strikethrough(strikethrough, color: markerColor.opacity(0.7))
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(fill)
    }
}

private struct LegendSwatch: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            Text(label)
        }
    }
}

private enum DiffColors {
    // Soft fills that stay readable in light and dark appearance.
    static let insertFill = Color.green.opacity(0.22)
    static let deleteFill = Color.red.opacity(0.22)
    static let replaceFill = Color.orange.opacity(0.18)
    static let insertMarker = Color.green
    static let deleteMarker = Color.red
}
