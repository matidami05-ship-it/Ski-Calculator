import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = CalculatorViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class CalculatorViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    override func loadView() {
        let config = WKWebViewConfiguration()
        // The page calls navigator.vibrate() on each key tap. iOS has no vibrate API, so route it to the Taptic Engine.
        let shim = "navigator.vibrate=function(){try{window.webkit.messageHandlers.haptic.postMessage(1)}catch(e){};return true};"
        config.userContentController.addUserScript(WKUserScript(source: shim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(self, name: "haptic")
        config.websiteDataStore = .default()   // keeps History, time card and saved settings between launches

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(named: "LaunchBG")
        webView.scrollView.backgroundColor = UIColor(named: "LaunchBG")
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        haptic.prepare()
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        haptic.impactOccurred()
        haptic.prepare()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
    }

    // Links to websites (like the exchange-rate credit) open in Safari instead of inside the app.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated, let url = action.request.url,
           let scheme = url.scheme, scheme == "http" || scheme == "https" {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { UIApplication.shared.open(url) }
        return nil
    }
}
