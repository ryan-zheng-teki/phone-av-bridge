import SwiftUI

#if os(iOS)
import AVFoundation
import UIKit
#endif

struct QrPairingSheet: View {
  @Binding var isPresented: Bool
  let onSubmitPayload: (String) -> Void

  #if os(iOS)
  @StateObject private var scanner = QrScannerController()
  #endif

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 12) {
        Text("Scan QR Pairing")
          .font(.headline)

        #if os(iOS)
        QrCameraPreview(session: scanner.session)
          .frame(maxWidth: .infinity)
          .frame(height: 220)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
          )

        if let status = scanner.statusMessage, !status.isEmpty {
          Text(status)
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          Text("Align QR code inside the frame.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        #else
        Text("Camera scanning is unavailable on this runtime.")
          .font(.footnote)
          .foregroundStyle(.secondary)
        #endif

        Button("Cancel") {
          isPresented = false
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("scanQrCancelButton")
      }
      .padding(16)
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      #if os(iOS)
      .onAppear {
        scanner.onCodeScanned = { rawPayload in
          submitPayload(rawPayload)
        }
        scanner.start()
      }
      .onDisappear {
        scanner.stop()
      }
      #endif
    }
  }

  private func submitPayload(_ rawPayload: String) {
    let trimmed = rawPayload.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return
    }
    onSubmitPayload(trimmed)
    isPresented = false
  }
}

#if os(iOS)
private final class QrScannerController: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
  let session = AVCaptureSession()

  @Published var statusMessage: String?

  var onCodeScanned: ((String) -> Void)?

  private let captureQueue = DispatchQueue(label: "org.autobyteus.phoneavbridge.qr-scanner")
  private var isConfigured = false
  private var isScanning = false

  func start() {
    #if targetEnvironment(simulator)
    updateStatus("Camera scanning is unavailable in simulator.")
    return
    #else
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      configureAndStart()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        guard let self else { return }
        if granted {
          self.configureAndStart()
        } else {
          self.updateStatus("Camera permission denied.")
        }
      }
    case .denied, .restricted:
      updateStatus("Camera permission denied.")
    @unknown default:
      updateStatus("Camera unavailable.")
    }
    #endif
  }

  func stop() {
    captureQueue.async { [weak self] in
      guard let self else { return }
      if self.session.isRunning {
        self.session.stopRunning()
      }
      self.isScanning = false
    }
  }

  private func configureAndStart() {
    captureQueue.async { [weak self] in
      guard let self else { return }

      if !self.isConfigured {
        self.session.beginConfiguration()
        defer {
          self.session.commitConfiguration()
        }

        self.session.sessionPreset = .high

        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
          self.updateStatus("Camera unavailable.")
          return
        }

        do {
          let input = try AVCaptureDeviceInput(device: videoDevice)
          guard self.session.canAddInput(input) else {
            self.updateStatus("Failed to access camera input.")
            return
          }
          self.session.addInput(input)
        } catch {
          self.updateStatus("Failed to initialize camera.")
          return
        }

        let output = AVCaptureMetadataOutput()
        guard self.session.canAddOutput(output) else {
          self.updateStatus("Failed to initialize QR scanner.")
          return
        }
        self.session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: self.captureQueue)
        output.metadataObjectTypes = [.qr]
        self.isConfigured = true
      }

      self.isScanning = true
      self.updateStatus(nil)
      if !self.session.isRunning {
        self.session.startRunning()
      }
    }
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard isScanning else {
      return
    }
    guard let qrObject = metadataObjects
      .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
      .first(where: { $0.type == .qr }),
      let payload = qrObject.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
      !payload.isEmpty
    else {
      return
    }

    isScanning = false
    if session.isRunning {
      session.stopRunning()
    }

    DispatchQueue.main.async { [weak self] in
      self?.onCodeScanned?(payload)
    }
  }

  private func updateStatus(_ value: String?) {
    DispatchQueue.main.async { [weak self] in
      self?.statusMessage = value
    }
  }
}

private struct QrCameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> QrPreviewView {
    let view = QrPreviewView()
    view.previewLayer.videoGravity = .resizeAspectFill
    view.previewLayer.session = session
    return view
  }

  func updateUIView(_ uiView: QrPreviewView, context: Context) {
    if uiView.previewLayer.session !== session {
      uiView.previewLayer.session = session
    }
  }
}

private final class QrPreviewView: UIView {
  override class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }

  var previewLayer: AVCaptureVideoPreviewLayer {
    layer as! AVCaptureVideoPreviewLayer
  }
}
#endif
