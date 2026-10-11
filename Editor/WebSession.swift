//
//  WebSession.swift
//  EditForth
//
//  Special workspace tab: embedded WKWebView (doc browser for Ask Forth /
//  forth-standard.org). Not a Forth source buffer.
//

import Foundation
import WebKit
import Combine

@MainActor
final class WebSession: NSObject, Identifiable, ObservableObject {
    let id = UUID()
    let webView: WKWebView

    @Published var title: String
    /// Address field text (may differ from webView.url while editing).
    @Published var address: String
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false

    init(url: URL) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let wv = WKWebView(frame: .zero, configuration: config)
        self.webView = wv
        self.title = url.host ?? "Web"
        self.address = url.absoluteString
        super.init()
        wv.navigationDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        load(url)
    }

    var currentURL: URL? { webView.url }

    func load(_ url: URL) {
        address = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
    }

    func goForward() {
        guard webView.canGoForward else { return }
        webView.goForward()
    }

    func reload() {
        webView.reload()
    }

    /// Load whatever is in the address field (adds https:// if no scheme).
    func loadAddressField() {
        var s = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        if !s.contains("://") {
            s = "https://" + s
        }
        guard let url = URL(string: s) else { return }
        load(url)
    }

    private func refreshChrome() {
        title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? webView.url?.host
            ?? title
        if let url = webView.url {
            address = url.absoluteString
        }
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
    }
}

extension WebSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        refreshChrome()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        refreshChrome()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        refreshChrome()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        refreshChrome()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        isLoading = false
        refreshChrome()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let scheme = (url.scheme ?? "").lowercased()
        switch scheme {
        case "http", "https", "about", "blob", "data":
            decisionHandler(.allow)
        case "file":
            // Local docs under the user tree are fine; other file: stays allowed for now.
            decisionHandler(.allow)
        default:
            decisionHandler(.cancel)
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
