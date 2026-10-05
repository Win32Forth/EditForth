import SwiftUI

/// Scaffold layout: editor above, Ping strip, Forth dock stub below.
/// Real Forth UI docking and IPC come later — see DESIGN.md.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            editorPane
            Divider()
            pingStrip
            Divider()
            forthDockStub
        }
        .frame(minWidth: 640, minHeight: 420)
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Editor")
                .font(.headline)
            Text("Source tabs and the Forth source editor will live here.")
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var pingStrip: some View {
        HStack {
            Text("Ping")
                .font(.subheadline.weight(.semibold))
            Text("stays in the editor whether Forth is docked or floating.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Spacer()
            Text("not connected")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var forthDockStub: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forth (dock)")
                .font(.headline)
            Text("Real Forth UI docks under Ping. Detach later as a lifecycle-tied window.")
                .foregroundStyle(.secondary)
            Text("EditForth is a separate project from 64Forth and 64Edit.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 140, idealHeight: 180)
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
}
