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

    // A copy of the iPhone launch screen (background + logo) laid over the page until it has drawn, so the hand-off is invisible.
    private let cover = UIView()
    private let launchLogo = UIImageView(image: UIImage(named: "LaunchLogo"))
    private var revealed = false

    override func loadView() {
        let config = WKWebViewConfiguration()
        // The page calls navigator.vibrate() on each key tap. iOS has no vibrate API, so route it to the Taptic Engine.
        let shim = "navigator.vibrate=function(){try{window.webkit.messageHandlers.haptic.postMessage(1)}catch(e){};return true};"
        config.userContentController.addUserScript(WKUserScript(source: shim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        // Tell the app once the page has drawn its first full frame with its own fonts.
        let ready = "(function(){function go(){requestAnimationFrame(function(){requestAnimationFrame(function(){try{window.webkit.messageHandlers.ready.postMessage(1)}catch(e){}})})}"
            + "try{(document.fonts&&document.fonts.ready?document.fonts.ready:Promise.resolve()).then(go,go)}catch(e){go()}})();"
        config.userContentController.addUserScript(WKUserScript(source: ready, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController.add(self, name: "haptic")
        config.userContentController.add(self, name: "ready")
        config.websiteDataStore = .default()   // keeps History, time card and saved settings between launches

        let root = UIView()
        root.backgroundColor = UIColor(named: "LaunchBG")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(named: "LaunchBG")
        webView.scrollView.backgroundColor = UIColor(named: "LaunchBG")
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(webView)

        cover.backgroundColor = UIColor(named: "LaunchBG")
        cover.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(cover)
        launchLogo.translatesAutoresizingMaskIntoConstraints = false
        cover.addSubview(launchLogo)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: root.topAnchor),
            webView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            cover.topAnchor.constraint(equalTo: root.topAnchor),
            cover.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            cover.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            launchLogo.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
            launchLogo.centerYAnchor.constraint(equalTo: cover.centerYAnchor)
        ])
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        haptic.prepare()
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        // Safety net: never leave the logo up if the ready signal doesn't arrive.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.reveal() }
    }

    private func reveal() {
        guard !revealed else { return }
        revealed = true
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: {
            self.cover.alpha = 0
            self.launchLogo.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }, completion: { _ in self.cover.removeFromSuperview() })
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "ready" { reveal(); return }
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
