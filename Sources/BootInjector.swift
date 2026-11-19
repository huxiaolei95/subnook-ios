import Foundation
import WebKit

/// 在页面脚本执行前注入：iOS 标记 + 已存数据
enum BootInjector {

    static func makeUserScript() -> WKUserScript {
        let raw = Store.shared.load() ?? "null"
        let source = """
        window.__IOS_MODE__ = true;
        window.__IOS_DATA__ = \(raw);
        window.__IOS_APPLY__ = function (json) {
          try {
            var obj = (typeof json === 'string') ? JSON.parse(json) : json;
            if (obj && obj.items) {
              window.__DESK_DATA__ = obj;
              if (typeof load === 'function') { load(); }
              if (typeof renderAll === 'function') { renderAll(); }
            }
          } catch (e) {}
        };
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }
}
