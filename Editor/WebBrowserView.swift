//
//  WebBrowserView.swift
//  EditForth
//
//  Chrome + WKWebView for a WebSession tab. Back/Forward sit at the top left.
//

import SwiftUI
import WebKit

struct WebBrowserView: View {
    @ObservedObject var session: WebSession
    var onSendToAskForth: () -> Void
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    session.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .buttonStyle(.borderless)
                .disabled(!session.canGoBack)
                .help("Back")
                .accessibilityLabel("Back")

                Button {
                    session.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .buttonStyle(.borderless)
                .disabled(!session.canGoForward)
                .help("Forward")
                .accessibilityLabel("Forward")

                TextField("Search or enter address", text: $session.address)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($addressFocused)
                    .help("Type a URL (forth-standard.org) or a search (OPEN-FILE Forth) and press Return / Go")
                    .onSubmit { session.loadAddressField() }

                Button("Go") {
                    session.loadAddressField()
                }
                .disabled(session.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Open the address, or search DuckDuckGo when the field is not a URL")

                Button {
                    session.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Reload")

                Button("Send to Ask Forth") {
                    onSendToAskForth()
                }
                .help("Append this page’s URL to the Ask Forth Prompt and show the panel")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)
            }

            if session.isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(height: 2)
            }

            WebViewHost(webView: session.webView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { applyPendingAddressFocus() }
        .onChange(of: session.pendingAddressFocus) { _, pending in
            if pending { applyPendingAddressFocus() }
        }
    }

    private func applyPendingAddressFocus() {
        guard session.pendingAddressFocus else { return }
        session.pendingAddressFocus = false
        // Defer so the tab chrome exists before focusing.
        DispatchQueue.main.async {
            addressFocused = true
        }
    }
}

/// Hosts an existing WKWebView owned by WebSession (keep-alive across tab switches).
private struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Session owns navigation state; nothing to push from SwiftUI.
    }
}
