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
    @State private var showLog = false
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
        .sheet(isPresented: $showLog) {
            LogOverlayView(bridge: webBridge)
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
                showLog = true
            } label: {
                Image(systemName: "terminal")
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

    private let consoleCaptureScript = """
    (function() {
      var _log = console.log.bind(console);
      var _warn = console.warn.bind(console);
      var _error = console.error.bind(console);
      function send(level, args) {
        var msg = Array.from(args).map(function(a) {
          try { return typeof a === 'object' ? JSON.stringify(a) : String(a); }
          catch(e) { return String(a); }
        }).join(' ');
        window.webkit.messageHandlers.consoleLog.postMessage({ level: level, message: msg });
      }
      console.log   = function() { _log.apply(console, arguments);   send('log',   arguments); };
      console.warn  = function() { _warn.apply(console, arguments);  send('warn',  arguments); };
      console.error = function() { _error.apply(console, arguments); send('error', arguments); };
      window.onerror = function(msg, src, line, col, err) {
        send('error', ['[onerror] ' + msg + ' @ ' + src + ':' + line]);
        return false;
      };
    })();
    """

    private let preLoadCompatibilityScript = """
    // Fix focus
    window.focus = function() {};
    window.top = window;
    document.hasFocus = function() { return true; };
    window.document.hasFocus = function() { return true; };

    // Fix sau khi page load xong
    window.addEventListener('load', function() {
        if (typeof SceneManager !== 'undefined') {
            SceneManager.isGameActive = function() { return true; };
        }
        if (typeof Utils !== 'undefined') {
            Utils.isNwjs = function() { return false; };
            Utils.isOptionValid = function(name) { return false; };
        }
        if (typeof Graphics !== 'undefined') {
            Graphics.printError = function(name, msg) {
                console.error('[RPG Error] ' + name + ': ' + msg);
            };
        }
        if (typeof WebAudio !== 'undefined') {
            document.addEventListener('touchstart', function() {
                if (WebAudio._context && WebAudio._context.state === 'suspended') {
                    WebAudio._context.resume();
                }
            }, { once: true });
        }
    }, false);
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
        userContentController.add(context.coordinator, name: "consoleLog")
        userContentController.addUserScript(
            WKUserScript(
                source: consoleCaptureScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
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

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "consoleLog")
        uiView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private weak var bridge: WebBridge?

        init(bridge: WebBridge) {
            self.bridge = bridge
        }

        @MainActor
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge?.didFinishPageLoad()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard
                message.name == "consoleLog",
                let payload = message.body as? [String: Any],
                let level = payload["level"] as? String,
                let text = payload["message"] as? String
            else {
                return
            }

            Task { @MainActor [weak bridge] in
                bridge?.appendLog(level: level, message: text)
            }
        }
    }
}

@MainActor
private final class WebBridge: ObservableObject {
    struct ConsoleEntry: Identifiable {
        let id = UUID()
        let level: String
        let message: String
        let time: Date
    }

    weak var webView: WKWebView?
    @Published var fps: Int = 0
    @Published var consoleLogs: [ConsoleEntry] = []

    private let game: Game
    private var fpsTimer: Timer?
    private var autoSaveTimer: Timer?

    init(game: Game) {
        self.game = game
    }

    func appendLog(level: String, message: String) {
        consoleLogs.append(ConsoleEntry(level: level, message: message, time: Date()))
        if consoleLogs.count > 200 {
            consoleLogs.removeFirst(consoleLogs.count - 200)
        }
    }

    func clearLogs() {
        consoleLogs.removeAll()
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

private struct LogOverlayView: View {
    @ObservedObject var bridge: WebBridge
    @Environment(\.dismiss) private var dismiss

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Text("Console")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)

                    Spacer()

                    Button("Copy All") {
                        let lines = bridge.consoleLogs.map { entry in
                            let time = Self.timeFormatter.string(from: entry.time)
                            return "[\(time)] [\(entry.level.uppercased())] \(entry.message)"
                        }
                        UIPasteboard.general.string = lines.joined(separator: "\n")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                    Button("Xoa") {
                        bridge.clearLogs()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                Divider()
                    .background(Color.white.opacity(0.2))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(bridge.consoleLogs) { entry in
                                logRow(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        scrollToBottom(proxy)
                    }
                    .onChange(of: bridge.consoleLogs.count) { _ in
                        scrollToBottom(proxy)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = bridge.consoleLogs.last?.id else {
            return
        }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.12)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    private func logRow(_ entry: WebBridge.ConsoleEntry) -> some View {
        let color = colorForLevel(entry.level)
        let time = Self.timeFormatter.string(from: entry.time)

        return HStack(alignment: .top, spacing: 6) {
            Text("[\(time)]")
                .foregroundColor(.gray)

            Image(systemName: iconForLevel(entry.level))
                .foregroundColor(color)

            Text(entry.level.uppercased())
                .foregroundColor(color)
                .fontWeight(.semibold)

            Text(entry.message)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(size: 11, weight: .regular, design: .monospaced))
    }

    private func iconForLevel(_ level: String) -> String {
        switch level.lowercased() {
        case "error":
            return "xmark.octagon.fill"
        case "warn":
            return "exclamationmark.triangle.fill"
        default:
            return "info.circle.fill"
        }
    }

    private func colorForLevel(_ level: String) -> Color {
        switch level.lowercased() {
        case "error":
            return .red
        case "warn":
            return .yellow
        default:
            return .primary
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
