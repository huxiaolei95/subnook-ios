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

        // 注册原生桥（JS 侧用 window.webkit.messageHandlers.store.postMessage 调用）
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

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator {
        var bridge: StoreBridge?
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
        // 安全转成 JS 字符串字面量
        if let d = try? JSONSerialization.data(withJSONObject: [s], options: []),
           let arr = String(data: d, encoding: .utf8) {
            return arr.dropFirst().dropLast().description
        }
        return "\"{}\""
    }
}
