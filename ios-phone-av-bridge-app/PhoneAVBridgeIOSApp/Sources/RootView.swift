import SwiftUI
import PhoneAVBridgeIOS

struct RootView: View {
  @StateObject private var viewModel: PhoneBridgeMainScreenViewModel

  init(config: AppConfig = .resolve()) {
    _viewModel = StateObject(
      wrappedValue: PhoneBridgeMainScreenViewModel(
        bootstrapBaseURL: config.hostBaseURL,
        deviceName: config.deviceName,
        deviceId: config.deviceId,
        cameraStreamURLProvider: { controls in
          if controls.cameraEnabled || controls.microphoneEnabled {
            return config.defaultCameraStreamURL
          }
          return nil
        }
      )
    )
  }

  var body: some View {
    PhoneBridgeMainScreen(viewModel: viewModel)
  }
}
