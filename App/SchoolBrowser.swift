// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import WebKit

struct BrowserDestination: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let login: Bool
}

struct SchoolBrowser: View {
    @EnvironmentObject var store: CampusStore
    @Environment(\.dismiss) private var dismiss
    let destination: BrowserDestination
    @State private var currentAddress = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(currentAddress.isEmpty ? destination.url.host ?? "" : currentAddress)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2).padding(8)
                if destination.login {
                    Text("请在学校官方页面登录并完成验证码，然后点“登录后同步”。App 不读取或保存密码。")
                        .font(.caption).padding(10).frame(maxWidth: .infinity).background(.indigo.opacity(0.08))
                }
                if let error { Text(error).font(.callout).foregroundStyle(.red).padding() }
                WebPage(url: destination.url, dataStore: store.webData, address: $currentAddress, error: $error)
            }
            .navigationTitle(destination.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                if destination.login {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("登录后同步") { dismiss(); Task { await store.sync() } }
                    }
                }
            }
        }
    }
}

private struct WebPage: UIViewRepresentable {
    let url: URL
    let dataStore: WKWebsiteDataStore
    @Binding var address: String
    @Binding var error: String?
    func makeCoordinator() -> Coordinator { Coordinator(address: $address, error: $error) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var address: String
        @Binding var error: String?
        init(address: Binding<String>, error: Binding<String?>) { _address = address; _error = error }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url, url.scheme == "https" || url.absoluteString == "about:blank" else {
                error = "初版仅支持 HTTPS 教务和认证页面。该跳转尚不受支持。"
                decisionHandler(.cancel); return
            }
            if action.targetFrame?.isMainFrame != false { address = url.host ?? "学校网页" }
            decisionHandler(.allow)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { address = webView.url?.host ?? ""; error = nil }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError failure: Error) {
            if (failure as NSError).code != NSURLErrorCancelled { error = failure.localizedDescription }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, navigationAction.request.url?.scheme == "https" { webView.load(navigationAction.request) }
            return nil
        }
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: "学校网页", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler() })
            guard let presenter = webView.window?.rootViewController else { completionHandler(); return }
            var top = presenter
            while let next = top.presentedViewController { top = next }
            top.present(alert, animated: true)
        }
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: "确认学校网页操作", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
            guard let presenter = webView.window?.rootViewController else { completionHandler(false); return }
            var top = presenter
            while let next = top.presentedViewController { top = next }
            top.present(alert, animated: true)
        }
    }
}
