//
//  SearchResultsView.swift
//  EditForth
//
//  Hit list for a SearchSession tab. Click opens the file at that line.
//

import SwiftUI

struct SearchResultsView: View {
    @ObservedObject var session: SearchSession
    @ObservedObject var workspace: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(session.status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                if session.isSearching {
                    ProgressView()
                        .controlSize(.small)
                    Button("Cancel") {
                        session.requestCancel()
                    }
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if session.hits.isEmpty && !session.isSearching {
                Text(session.status == "Cancelled" ? "Search cancelled" : "No matches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(session.hits) { hit in
                    Button {
                        open(hit)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(displayPath(for: hit))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text(":\(hit.line)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(hit.snippet)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }

    private func displayPath(for hit: SearchHit) -> String {
        let path = hit.fileURL.path
        for root in session.roots {
            let rp = root.path.hasSuffix("/") ? root.path : root.path + "/"
            if path.hasPrefix(rp) {
                return String(path.dropFirst(rp.count))
            }
            if path.hasPrefix(root.path) {
                return String(path.dropFirst(root.path.count).drop(while: { $0 == "/" }))
            }
        }
        return hit.fileURL.lastPathComponent
    }

    private func open(_ hit: SearchHit) {
        workspace.openURL(hit.fileURL, viewMode: false, line: hit.line)
    }
}
