import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit

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
    let onCodeScanned: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        let session = AVCaptureSession()

        // Input: camera posteriore
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return view
        }
        session.addInput(input)

        // Output: metadata (barcode)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            return view
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
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

        // Preview layer
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill

        context.coordinator.session = session
        session.startRunning()

        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.videoPreviewLayer.frame = uiView.bounds
    }

    static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: Coordinator) {
        coordinator.session?.stopRunning()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var onCodeScanned: (String) -> Void
        var session: AVCaptureSession?
        private var didCaptureCode = false

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
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
            session?.stopRunning()

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

    init(
        title: String = "Scanner barcode",
        onCodeScanned: @escaping (String) -> Void
    ) {
        self.title = title
        self.onCodeScanned = onCodeScanned
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Camera
            BarcodeScannerView { code in
                onCodeScanned(code)
                dismiss()
            }
            .ignoresSafeArea()

            // Overlay grafico (linea rossa + maschera)
            ScannerOverlay()

            // Header con titolo + bottone chiudi
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

                Text("Allinea il codice a barre alla linea rossa per leggere automaticamente.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding()
        }
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
