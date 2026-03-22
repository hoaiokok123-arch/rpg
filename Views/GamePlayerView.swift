import SwiftUI
import UIKit
import WebKit
import Photos

struct GamePlayerView: View {
    let game: Game

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var gameLibrary: GameLibrary

    @StateObject private var webBridge: WebBridge

    @State private var showFPS = true
    @State private var feedbackMessage = ""
    @State private var showFeedback = false

    init(game: Game) {
        self.game = game
        _webBridge = StateObject(wrappedValue: WebBridge(game: game))
    }

    var body: some View {
        ZStack {
            GameWebView(game: game, bridge: webBridge)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                gamepad
            }

            if showFPS {
                fpsBadge
            }
        }
        .navigationBarBackButtonHidden(true)
        .statusBarHidden()
        .onAppear {
            OrientationController.lockLandscape()
            webBridge.startAutoSave()
            webBridge.startFPSMonitoring()
        }
        .onDisappear {
            webBridge.persistSaveData()
            webBridge.stopAutoSave()
            webBridge.stopFPSMonitoring()
            OrientationController.unlockDefault()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                webBridge.persistSaveData()
            }
            if phase == .active {
                if showFPS {
                    webBridge.startFPSMonitoring()
                }
            }
        }
        .alert(feedbackMessage, isPresented: $showFeedback) {
            Button("OK", role: .cancel) {}
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Circle())
            }

            Spacer()

            Button {
                Task {
                    await captureScreenshot()
                }
            } label: {
                Image(systemName: "camera")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Circle())
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showFPS.toggle()
                }

                if showFPS {
                    webBridge.startFPSMonitoring()
                } else {
                    webBridge.stopFPSMonitoring()
                }
            } label: {
                Image(systemName: showFPS ? "speedometer" : "speedometer.slash")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 10)
    }

    private var fpsBadge: some View {
        VStack {
            HStack {
                Spacer()
                Text("\(webBridge.fps) FPS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.top, 52)
        .padding(.trailing, 12)
        .allowsHitTesting(false)
    }

    private var gamepad: some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom) {
                dPad
                Spacer()
                abButtons
            }

            HStack(spacing: 16) {
                flatButton(title: "Select") {
                    webBridge.send(.select)
                }
                flatButton(title: "Start") {
                    webBridge.send(.start)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
        .opacity(0.6)
    }

    private var dPad: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer(minLength: 0)
                iconButton(systemName: "arrow.up") {
                    webBridge.send(.up)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                iconButton(systemName: "arrow.left") {
                    webBridge.send(.left)
                }
                Color.clear
                    .frame(width: 52, height: 52)
                iconButton(systemName: "arrow.right") {
                    webBridge.send(.right)
                }
            }

            HStack {
                Spacer(minLength: 0)
                iconButton(systemName: "arrow.down") {
                    webBridge.send(.down)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var abButtons: some View {
        VStack(spacing: 12) {
            circleButton(title: "A", color: .red) {
                webBridge.send(.a)
            }
            circleButton(title: "B", color: .blue) {
                webBridge.send(.b)
            }
        }
    }

    private func captureScreenshot() async {
        do {
            let image = try await webBridge.takeScreenshot()
            try await PhotoSaver.saveToPhotoLibrary(image: image)
            feedbackMessage = "Da luu screenshot vao Photos."
            showFeedback = true
        } catch {
            feedbackMessage = "Khong the luu screenshot: \(error.localizedDescription)"
            showFeedback = true
        }
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func circleButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(color)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func flatButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct GameWebView: UIViewRepresentable {
    let game: Game
    @ObservedObject var bridge: WebBridge

    private let preLoadCompatibilityScript = """
    (function() {
      function patchSceneManager() {
        if (typeof window.SceneManager !== 'undefined') {
          window.SceneManager.isGameActive = function() { return true; };
          return true;
        }
        return false;
      }

      patchSceneManager();
      var patchTimer = setInterval(function() {
        if (patchSceneManager()) {
          clearInterval(patchTimer);
        }
      }, 50);
      window.addEventListener('load', function() {
        patchSceneManager();
        clearInterval(patchTimer);
      }, { once: true });

      if (typeof AudioContext !== 'undefined') {
        var _origAudio = AudioContext;
        AudioContext = function() {
          var ctx = new _origAudio();
          document.addEventListener('touchstart', function() {
            if (ctx.state === 'suspended') ctx.resume();
          }, { once: true });
          return ctx;
        };
      }

      window.focus = function() {};
      document.hasFocus = function() { return true; };

      if (typeof Graphics !== 'undefined') {
        Graphics.printError = function(name, message) {
          console.error(name + ': ' + message);
        };
      } else {
        var setGraphicsPatch = setInterval(function() {
          if (typeof Graphics !== 'undefined') {
            Graphics.printError = function(name, message) {
              console.error(name + ': ' + message);
            };
            clearInterval(setGraphicsPatch);
          }
        }, 50);
        window.addEventListener('load', function() {
          if (typeof Graphics !== 'undefined') {
            Graphics.printError = function(name, message) {
              console.error(name + ': ' + message);
            };
          }
          clearInterval(setGraphicsPatch);
        }, { once: true });
      }
    })();
    """

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        if config.preferences.responds(to: Selector(("setAllowFileAccess:"))) {
            config.preferences.setValue(true, forKey: "allowFileAccess")
        }
        if config.preferences.responds(to: Selector(("setAllowFileAccessFromFileURLs:"))) {
            config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        }
        if config.responds(to: Selector(("setAllowUniversalAccessFromFileURLs:"))) {
            config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        }

        let userContentController = WKUserContentController()
        userContentController.addUserScript(
            WKUserScript(
                source: preLoadCompatibilityScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        if let restoreScript = GameSaveStore.restoreScript(for: game) {
            userContentController.addUserScript(
                WKUserScript(
                    source: restoreScript,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                )
            )
        }
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = true

        bridge.webView = webView

        let gameFolderURL = URL(fileURLWithPath: game.path, isDirectory: true)
        let indexURL = gameFolderURL
            .appendingPathComponent("www", isDirectory: true)
            .appendingPathComponent("index.html")

        if FileManager.default.fileExists(atPath: indexURL.path) {
            webView.loadFileURL(indexURL, allowingReadAccessTo: gameFolderURL)
        } else {
            webView.loadHTMLString(
                "<html><body style='background:black;color:white;display:flex;align-items:center;justify-content:center;'>Missing www/index.html</body></html>",
                baseURL: nil
            )
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        bridge.webView = uiView
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private weak var bridge: WebBridge?

        init(bridge: WebBridge) {
            self.bridge = bridge
        }

        @MainActor
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge?.didFinishPageLoad()
        }
    }
}

@MainActor
private final class WebBridge: ObservableObject {
    weak var webView: WKWebView?
    @Published var fps: Int = 0

    private let game: Game
    private var fpsTimer: Timer?
    private var autoSaveTimer: Timer?

    init(game: Game) {
        self.game = game
    }

    func didFinishPageLoad() {
        setupFPSTrackerScript()
    }

    func send(_ input: GameInput) {
        let script = """
        (function() {
          var key = "\(input.key)";
          var code = "\(input.code)";
          var keyCode = \(input.keyCode);
          function makeEvent(type) {
            return new KeyboardEvent(type, { key: key, code: code, keyCode: keyCode, which: keyCode, bubbles: true });
          }
          document.dispatchEvent(makeEvent("keydown"));
          window.dispatchEvent(makeEvent("keydown"));
          setTimeout(function() {
            document.dispatchEvent(makeEvent("keyup"));
            window.dispatchEvent(makeEvent("keyup"));
          }, 16);
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func startFPSMonitoring() {
        stopFPSMonitoring()
        fpsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.pollFPS()
            }
        }
        fpsTimer?.tolerance = 0.1
    }

    func stopFPSMonitoring() {
        fpsTimer?.invalidate()
        fpsTimer = nil
    }

    func startAutoSave() {
        stopAutoSave()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.persistSaveData()
            }
        }
        autoSaveTimer?.tolerance = 1.0
    }

    func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    func persistSaveData() {
        let script = """
        (function() {
          var out = {};
          for (var i = 0; i < localStorage.length; i++) {
            var key = localStorage.key(i);
            var value = localStorage.getItem(key);
            if (value !== null) {
              out[key] = value;
            }
          }
          return JSON.stringify(out);
        })();
        """
        let currentGame = game
        webView?.evaluateJavaScript(script) { result, _ in
            guard let json = result as? String else {
                return
            }
            try? GameSaveStore.writeLocalStorageJSON(json, for: currentGame)
        }
    }

    func takeScreenshot() async throws -> UIImage {
        guard let webView else {
            throw ScreenshotError.webViewUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ScreenshotError.unknown)
                }
            }
        }
    }

    private func setupFPSTrackerScript() {
        webView?.evaluateJavaScript(
            """
            (function() {
              if (window.__rpgPlayerFPSInstalled) return;
              window.__rpgPlayerFPSInstalled = true;
              window.__rpgPlayerFPS = 0;
              var last = performance.now();
              var frames = 0;
              function tick(now) {
                frames += 1;
                if (now - last >= 1000) {
                  window.__rpgPlayerFPS = frames;
                  frames = 0;
                  last = now;
                }
                requestAnimationFrame(tick);
              }
              requestAnimationFrame(tick);
            })();
            """,
            completionHandler: nil
        )
    }

    private func pollFPS() {
        webView?.evaluateJavaScript("window.__rpgPlayerFPS || 0") { [weak self] result, _ in
            Task { @MainActor in
                guard let self else {
                    return
                }
                if let value = result as? Int {
                    self.fps = value
                } else if let number = result as? NSNumber {
                    self.fps = number.intValue
                } else {
                    self.fps = 0
                }
            }
        }
    }
}

private enum GameInput {
    case up
    case down
    case left
    case right
    case a
    case b
    case start
    case select

    var key: String {
        switch self {
        case .up:
            return "ArrowUp"
        case .down:
            return "ArrowDown"
        case .left:
            return "ArrowLeft"
        case .right:
            return "ArrowRight"
        case .a:
            return "z"
        case .b:
            return "x"
        case .start:
            return "Enter"
        case .select:
            return "Escape"
        }
    }

    var code: String {
        switch self {
        case .up:
            return "ArrowUp"
        case .down:
            return "ArrowDown"
        case .left:
            return "ArrowLeft"
        case .right:
            return "ArrowRight"
        case .a:
            return "KeyZ"
        case .b:
            return "KeyX"
        case .start:
            return "Enter"
        case .select:
            return "Escape"
        }
    }

    var keyCode: Int {
        switch self {
        case .up:
            return 38
        case .down:
            return 40
        case .left:
            return 37
        case .right:
            return 39
        case .a:
            return 90
        case .b:
            return 88
        case .start:
            return 13
        case .select:
            return 27
        }
    }
}

private enum GameSaveStore {
    static func restoreScript(for game: Game) -> String? {
        guard let json = try? readLocalStorageJSON(for: game) else {
            return nil
        }
        let payload = Data(json.utf8).base64EncodedString()

        return """
        (function() {
          try {
            var raw = atob('\(payload)');
            var data = JSON.parse(raw);
            Object.keys(data).forEach(function(key) {
              localStorage.setItem(key, String(data[key]));
            });
          } catch (e) {
            console.log('restore save failed', e);
          }
        })();
        """
    }

    static func writeLocalStorageJSON(_ json: String, for game: Game) throws {
        let saveFileURL = try saveFileURL(for: game)
        try json.write(to: saveFileURL, atomically: true, encoding: .utf8)
    }

    private static func readLocalStorageJSON(for game: Game) throws -> String {
        let saveFileURL = try saveFileURL(for: game)
        return try String(contentsOf: saveFileURL, encoding: .utf8)
    }

    private static func saveFileURL(for game: Game) throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let savesRootURL = documentsURL.appendingPathComponent("Saves", isDirectory: true)
        if !fileManager.fileExists(atPath: savesRootURL.path) {
            try fileManager.createDirectory(at: savesRootURL, withIntermediateDirectories: true)
        }

        let gameSaveURL = savesRootURL.appendingPathComponent(game.id.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: gameSaveURL.path) {
            try fileManager.createDirectory(at: gameSaveURL, withIntermediateDirectories: true)
        }

        return gameSaveURL.appendingPathComponent("localStorage.json")
    }
}

private enum PhotoSaveError: LocalizedError {
    case denied
    case failed

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Khong du quyen truy cap Photos."
        case .failed:
            return "Khong the luu screenshot."
        }
    }
}

private enum ScreenshotError: LocalizedError {
    case webViewUnavailable
    case unknown

    var errorDescription: String? {
        switch self {
        case .webViewUnavailable:
            return "WebView chua san sang."
        case .unknown:
            return "Khong the chup man hinh."
        }
    }
}

private enum PhotoSaver {
    static func saveToPhotoLibrary(image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoSaveError.denied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: PhotoSaveError.failed)
                }
            }
        }
    }
}

private enum OrientationController {
    static func lockLandscape() {
        AppDelegate.orientationLock = .landscape
        updateOrientation(mask: .landscape, fallback: .landscapeRight)
    }

    static func unlockDefault() {
        AppDelegate.orientationLock = .all
        updateOrientation(mask: .all, fallback: .portrait)
    }

    private static func updateOrientation(mask: UIInterfaceOrientationMask, fallback: UIInterfaceOrientation) {
        if #available(iOS 16.0, *),
           let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        } else {
            UIDevice.current.setValue(fallback.rawValue, forKey: "orientation")
        }
        UIViewController.attemptRotationToDeviceOrientation()
    }
}
