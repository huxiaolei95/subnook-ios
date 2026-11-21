import SwiftUI
import UIKit
import WebKit

@main
struct SubnookApp: App {
    var body: some Scene {
        WindowGroup {
            WebShell()
                .ignoresSafeArea(edges: .all)
                .preferredColorScheme(.light)
        }
    }
}

struct WebShell: UIViewRepresentable {

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []

        // 原生桥（JS 侧用 window.webkit.messageHandlers.store.postMessage 调用）
        let handler = StoreBridge()
        cfg.userContentController.add(handler, name: "store")
        context.coordinator.bridge = handler

        // 注入：iOS 标记 + 初始数据 + 存储层替换
        let boot = BootInjector.makeUserScript()
        cfg.userContentController.addUserScript(boot)

        let web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1)
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsBackForwardNavigationGestures = false

        // 关键：没有这行，JS 的 confirm()/alert() 一律静默返回 false
        web.uiDelegate = context.coordinator

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKUIDelegate {
        var bridge: StoreBridge?

        private func topVC() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes
            let ws = scenes.compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
                ?? scenes.compactMap { $0 as? UIWindowScene }.first
            var vc = (ws?.windows.first { $0.isKeyWindow } ?? ws?.windows.first)?.rootViewController
            while let p = vc?.presentedViewController { vc = p }
            return vc
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            DispatchQueue.main.async {
                guard let vc = self.topVC() else { completionHandler(false); return }
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                    completionHandler(false)
                })
                alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                    completionHandler(true)
                })
                vc.present(alert, animated: true)
            }
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            DispatchQueue.main.async {
                guard let vc = self.topVC() else { completionHandler(); return }
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "好", style: .default) { _ in
                    completionHandler()
                })
                vc.present(alert, animated: true)
            }
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            DispatchQueue.main.async {
                guard let vc = self.topVC() else { completionHandler(nil); return }
                let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
                alert.addTextField { tf in tf.text = defaultText }
                alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                    completionHandler(nil)
                })
                alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                    completionHandler(alert.textFields?.first?.text)
                })
                vc.present(alert, animated: true)
            }
        }
    }
}

// 持有 bridge，避免被回收
final class StoreBridge: NSObject, WKScriptMessageHandler {
    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "save":
            if let payload = body["data"] as? String {
                Store.shared.save(json: payload)
            }
        case "load":
            if let data = Store.shared.load() {
                let js = "window.__IOS_APPLY__(\(jsonLiteral(data)))"
                DispatchQueue.main.async {
                    (message.webView)?.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        default:
            break
        }
    }

    private func jsonLiteral(_ s: String) -> String {
        if let d = try? JSONSerialization.data(withJSONObject: [s], options: []),
           let arr = String(data: d, encoding: .utf8) {
            return arr.dropFirst().dropLast().description
        }
        return "\"{}\""
    }
}
