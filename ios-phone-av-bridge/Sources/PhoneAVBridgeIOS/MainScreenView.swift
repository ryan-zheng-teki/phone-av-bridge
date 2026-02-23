import SwiftUI

public struct PhoneBridgeMainScreen: View {
  @ObservedObject private var viewModel: PhoneBridgeMainScreenViewModel
  @State private var qrSheetPresented = false

  public init(viewModel: PhoneBridgeMainScreenViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    let state = viewModel.state

    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Phone AV Bridge")
          .font(.title2.weight(.semibold))

        Text("Use your phone camera, microphone, and speaker on your computer.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        GroupBox {
          VStack(alignment: .leading, spacing: 8) {
            Text(state.statusTitle)
              .font(.headline)
              .accessibilityIdentifier("statusTitleText")
            Text(state.statusDetail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .accessibilityIdentifier("statusDetailText")
            Text(state.hostSummary)
              .font(.footnote)
              .foregroundStyle(.secondary)
              .accessibilityIdentifier("hostSummaryText")
            Text("Hosts")
              .font(.caption.weight(.semibold))
              .padding(.top, 4)

            if state.hostSelection.candidates.isEmpty {
              Text(state.hostCandidatesHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
              VStack(alignment: .leading, spacing: 6) {
                ForEach(state.hostSelection.candidates, id: \.baseURL) { host in
                  Button {
                    viewModel.selectHost(baseURL: host.baseURL)
                  } label: {
                    HStack(alignment: .top, spacing: 8) {
                      Image(systemName: state.hostSelection.selectedBaseURL == host.baseURL ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(state.hostSelection.selectedBaseURL == host.baseURL ? Color.accentColor : Color.secondary)
                      Text(state.hostCandidateLabel(host))
                        .font(.footnote)
                        .foregroundStyle(.primary)
                      Spacer(minLength: 0)
                    }
                  }
                  .buttonStyle(.plain)
                  .disabled(state.pairingInProgress)
                }
              }
            }

            Text(state.hostCandidatesHint)
              .font(.footnote)
              .foregroundStyle(.secondary)

            Text(state.issuesText)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Button(state.primaryHostActionLabel) {
          Task { await viewModel.performPrimaryHostAction() }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!state.canTapPrimaryAction)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("primaryHostActionButton")

        Button("Scan QR Pairing") {
          qrSheetPresented = true
        }
        .buttonStyle(.bordered)
        .disabled(!state.canTapScanQr)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("scanQrButton")
        .sheet(isPresented: $qrSheetPresented) {
          QrPairingSheet(isPresented: $qrSheetPresented) { payload in
            Task {
              await viewModel.performQrPairing(rawPayload: payload)
            }
          }
        }

        Text("Steps:\n1. Open Phone AV Bridge Host on your computer.\n2. Select a host, then tap Pair (or use Scan QR).\n3. If already paired, select a different host and tap Switch.\n4. Enable Camera, Microphone, or Speaker here on phone.")
          .font(.footnote)
          .foregroundStyle(.secondary)

        GroupBox {
          VStack(alignment: .leading, spacing: 10) {
            Toggle(
              "Enable Camera",
              isOn: Binding(
                get: { state.controls.cameraEnabled },
                set: { newValue in
                  Task { await viewModel.setCameraEnabled(newValue) }
                }
              )
            )
            .disabled(!state.cameraControlEnabled)
            .accessibilityIdentifier("cameraToggle")

            Text("Camera Lens")
              .font(.footnote)
              .foregroundStyle(.secondary)

            Picker("Camera Lens", selection: Binding(
              get: { state.controls.cameraLens },
              set: { newValue in
                Task { await viewModel.setCameraLens(newValue) }
              }
            )) {
              Text("Back").tag(CameraLensOption.back)
              Text("Front").tag(CameraLensOption.front)
            }
            .pickerStyle(.segmented)
            .disabled(!state.cameraLensEnabled)

            Text("Orientation Mode")
              .font(.footnote)
              .foregroundStyle(.secondary)

            Picker("Orientation Mode", selection: Binding(
              get: { state.controls.cameraOrientation },
              set: { newValue in
                Task { await viewModel.setCameraOrientation(newValue) }
              }
            )) {
              Text("Auto").tag(CameraOrientationOption.auto)
              Text("Portrait").tag(CameraOrientationOption.portrait)
              Text("Landscape").tag(CameraOrientationOption.landscape)
            }
            .pickerStyle(.segmented)
            .disabled(!state.cameraOrientationEnabled)

            Toggle(
              "Enable Microphone",
              isOn: Binding(
                get: { state.controls.microphoneEnabled },
                set: { newValue in
                  Task { await viewModel.setMicrophoneEnabled(newValue) }
                }
              )
            )
            .disabled(!state.microphoneControlEnabled)
            .accessibilityIdentifier("microphoneToggle")

            Toggle(
              "Enable Speaker",
              isOn: Binding(
                get: { state.controls.speakerEnabled },
                set: { newValue in
                  Task { await viewModel.setSpeakerEnabled(newValue) }
                }
              )
            )
            .disabled(!state.speakerControlEnabled)
            .accessibilityIdentifier("speakerToggle")
          }
        }

        Text("Tip: this phone is the controller for camera, microphone, and speaker. Keep this app in foreground while testing.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .padding(16)
    }
    .task {
      await viewModel.onAppear()
    }
  }
}
