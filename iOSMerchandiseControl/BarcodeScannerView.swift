import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit

private enum ScannerScreenState: Equatable {
    case authorizing
    case permissionDenied
    case restricted
    case cameraUnavailable
    case startingSession
    case ready
    case sessionSetupFailed

    var showsScannerView: Bool {
        switch self {
        case .startingSession, .ready:
            return true
        default:
            return false
        }
    }

    var showsOverlay: Bool {
        self == .ready
    }

    var showsInstructions: Bool {
        showsScannerView
    }
}

/// UIView che mostra direttamente l'anteprima della camera
final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

/// Wrapper UIKit → SwiftUI che espone un callback con il barcode letto
struct BarcodeScannerView: UIViewRepresentable {
    let shouldRunSession: Bool
    let onCodeScanned: (String) -> Void
    let onSessionReady: () -> Void
    let onSessionSetupFailed: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCodeScanned: onCodeScanned,
            onSessionReady: onSessionReady,
            onSessionSetupFailed: onSessionSetupFailed
        )
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.backgroundColor = .black
        context.coordinator.updateCallbacks(
            onCodeScanned: onCodeScanned,
            onSessionReady: onSessionReady,
            onSessionSetupFailed: onSessionSetupFailed
        )
        context.coordinator.attachPreview(to: view)
        context.coordinator.updateSessionState(shouldRun: shouldRunSession)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.videoPreviewLayer.frame = uiView.bounds
        context.coordinator.updateCallbacks(
            onCodeScanned: onCodeScanned,
            onSessionReady: onSessionReady,
            onSessionSetupFailed: onSessionSetupFailed
        )
        context.coordinator.updateSessionState(shouldRun: shouldRunSession)
    }

    static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: Coordinator) {
        uiView.videoPreviewLayer.session = nil
        coordinator.teardownSession()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let session = AVCaptureSession()
        private let sessionQueue = DispatchQueue(label: "iOSMerchandiseControl.BarcodeScanner.session")

        var onCodeScanned: (String) -> Void
        var onSessionReady: () -> Void
        var onSessionSetupFailed: () -> Void

        private var didCaptureCode = false
        private var didEmitSessionReady = false
        private var didEmitSetupFailure = false
        private var didEncounterSetupFailure = false
        private var isConfigured = false
        private var isTornDown = false
        private var shouldRunSession = false

        init(
            onCodeScanned: @escaping (String) -> Void,
            onSessionReady: @escaping () -> Void,
            onSessionSetupFailed: @escaping () -> Void
        ) {
            self.onCodeScanned = onCodeScanned
            self.onSessionReady = onSessionReady
            self.onSessionSetupFailed = onSessionSetupFailed
        }

        func updateCallbacks(
            onCodeScanned: @escaping (String) -> Void,
            onSessionReady: @escaping () -> Void,
            onSessionSetupFailed: @escaping () -> Void
        ) {
            self.onCodeScanned = onCodeScanned
            self.onSessionReady = onSessionReady
            self.onSessionSetupFailed = onSessionSetupFailed
        }

        func attachPreview(to view: CameraPreviewView) {
            view.videoPreviewLayer.session = session
            view.videoPreviewLayer.videoGravity = .resizeAspectFill
        }

        func updateSessionState(shouldRun: Bool) {
            sessionQueue.async { [weak self] in
                guard let self else { return }
                self.shouldRunSession = shouldRun
                self.applyDesiredSessionState()
            }
        }

        func teardownSession() {
            sessionQueue.async { [weak self] in
                guard let self else { return }
                self.isTornDown = true
                self.shouldRunSession = false

                if self.session.isRunning {
                    self.session.stopRunning()
                }

                guard self.isConfigured else { return }

                self.session.beginConfiguration()
                for input in self.session.inputs {
                    self.session.removeInput(input)
                }
                for output in self.session.outputs {
                    self.session.removeOutput(output)
                }
                self.session.commitConfiguration()
                self.isConfigured = false
            }
        }

        private func applyDesiredSessionState() {
            guard !isTornDown else { return }

            if shouldRunSession {
                guard !didEncounterSetupFailure else { return }
                guard configureSessionIfNeeded() else { return }

                guard !session.isRunning else { return }

                session.startRunning()
                if session.isRunning {
                    reportSessionReadyIfNeeded()
                } else {
                    didEncounterSetupFailure = true
                    reportSetupFailureIfNeeded()
                }
            } else if session.isRunning {
                session.stopRunning()
            }
        }

        private func configureSessionIfNeeded() -> Bool {
            guard !isConfigured else { return true }

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                didEncounterSetupFailure = true
                reportSetupFailureIfNeeded()
                return false
            }

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                didEncounterSetupFailure = true
                reportSetupFailureIfNeeded()
                return false
            }

            session.beginConfiguration()
            session.addInput(input)
            session.addOutput(output)
            session.commitConfiguration()

            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [
                .ean13,
                .ean8,
                .upce,
                .code39,
                .code39Mod43,
                .code93,
                .code128,
                .qr
            ]

            isConfigured = true
            return true
        }

        private func reportSessionReadyIfNeeded() {
            guard !didEmitSessionReady, !isTornDown else { return }
            didEmitSessionReady = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onSessionReady()
            }
        }

        private func reportSetupFailureIfNeeded() {
            guard !didEmitSetupFailure, !isTornDown else { return }
            didEmitSetupFailure = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onSessionSetupFailed()
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didCaptureCode,
                  let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = metadataObject.stringValue,
                  !value.isEmpty else {
                return
            }

            didCaptureCode = true
            sessionQueue.async { [weak self] in
                guard let self, self.session.isRunning else { return }
                self.session.stopRunning()
            }

            // Feedback sonoro
            AudioServicesPlaySystemSound(1057) // piccolo "tick" di sistema

            // Feedback tattile
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            onCodeScanned(value)
        }
    }
}

/// Schermata intera da usare come .sheet in SwiftUI
struct ScannerView: View {
    let title: String
    let onCodeScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var screenState: ScannerScreenState = .authorizing
    @State private var didRunInitialEvaluation = false
    @State private var didRequestAccess = false

    init(
        title: String = L("scanner.default_title"),
        onCodeScanned: @escaping (String) -> Void
    ) {
        self.title = title
        self.onCodeScanned = onCodeScanned
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
                .ignoresSafeArea()

            scannerContent

            header
        }
        .onAppear {
            guard !didRunInitialEvaluation else { return }
            didRunInitialEvaluation = true
            refreshScannerState(requestAccessIfNeeded: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    @ViewBuilder
    private var scannerContent: some View {
        if screenState.showsScannerView {
            BarcodeScannerView(
                shouldRunSession: scenePhase == .active,
                onCodeScanned: handleCodeScanned,
                onSessionReady: handleSessionReady,
                onSessionSetupFailed: handleSessionSetupFailed
            )
            .ignoresSafeArea()

            if screenState == .startingSession {
                ScannerStatusOverlay(message: L("scanner.status.starting"))
            }

            if screenState.showsOverlay {
                ScannerOverlay()
            }
        } else {
            switch screenState {
            case .authorizing:
                ScannerStatusOverlay(message: L("scanner.status.authorizing"))
            case .permissionDenied:
                ScannerFallbackView(
                    iconName: "camera.slash.fill",
                    message: L("scanner.fallback.permission_denied.message"),
                    actionTitle: L("scanner.action.open_settings"),
                    action: openAppSettings
                )
            case .restricted:
                ScannerFallbackView(
                    iconName: "hand.raised.fill",
                    message: L("scanner.fallback.restricted.message")
                )
            case .cameraUnavailable:
                ScannerFallbackView(
                    iconName: "video.slash.fill",
                    message: L("scanner.fallback.camera_unavailable.message")
                )
            case .sessionSetupFailed:
                ScannerFallbackView(
                    iconName: "exclamationmark.triangle.fill",
                    message: L("scanner.fallback.session_failed.message")
                )
            case .startingSession, .ready:
                EmptyView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
            }

            if screenState.showsInstructions {
                Text(L("scanner.instructions"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.30))
        )
        .padding()
    }

    private func handleCodeScanned(_ code: String) {
        onCodeScanned(code)
        dismiss()
    }

    private func handleSessionReady() {
        guard screenState == .startingSession else { return }
        screenState = .ready
    }

    private func handleSessionSetupFailed() {
        switch screenState {
        case .startingSession, .ready:
            screenState = .sessionSetupFailed
        default:
            break
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard didRunInitialEvaluation else { return }

        switch newPhase {
        case .active:
            let shouldPreserveOperationalState = screenState == .startingSession || screenState == .ready
            refreshScannerState(
                requestAccessIfNeeded: false,
                preserveOperationalState: shouldPreserveOperationalState
            )
        case .inactive, .background:
            break
        @unknown default:
            break
        }
    }

    private func refreshScannerState(
        requestAccessIfNeeded: Bool,
        preserveOperationalState: Bool = false
    ) {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {
        case .notDetermined:
            screenState = .authorizing

            guard requestAccessIfNeeded, !didRequestAccess else { return }
            didRequestAccess = true

            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async {
                    refreshScannerState(requestAccessIfNeeded: false)
                }
            }

        case .restricted:
            screenState = .restricted

        case .denied:
            screenState = .permissionDenied

        case .authorized:
            guard AVCaptureDevice.default(for: .video) != nil else {
                screenState = .cameraUnavailable
                return
            }

            if preserveOperationalState, screenState == .ready {
                screenState = .ready
            } else if preserveOperationalState, screenState == .startingSession {
                screenState = .startingSession
            } else {
                screenState = .startingSession
            }

        @unknown default:
            screenState = .sessionSetupFailed
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

private struct ScannerFallbackView: View {
    let iconName: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: iconName)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.80))
    }
}

private struct ScannerStatusOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)

            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.65))
    }
}

private struct ScannerOverlay: View {
    @State private var animateLine = false

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let lineWidth = width * 0.8

            ZStack {
                // Oscuriamo leggermente sopra e sotto la zona centrale
                VStack(spacing: 0) {
                    Color.black.opacity(0.45)
                    Spacer()
                    Color.black.opacity(0.45)
                }

                // Linea rossa "laser" al centro, animata su e giù
                Rectangle()
                    .fill(Color.red)
                    .frame(width: lineWidth, height: 2)
                    .offset(y: animateLine ? height * 0.12 : -height * 0.12)
                    .animation(
                        .linear(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: animateLine
                    )
            }
            .onAppear { animateLine = true }
        }
        .allowsHitTesting(false)   // non blocca i tapp su chiusura ecc.
    }
}
