import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                Spacer()

                // Thumbnail of last captured image
                HStack {
                    if let image = camera.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.5), lineWidth: 1)
                            )
                            .padding(.leading, 24)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)

                // Controls
                HStack {
                    // Flash button
                    Button {
                        camera.cycleFlashMode()
                    } label: {
                        Image(systemName: flashIconName)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                    }

                    Spacer()

                    // Shutter button
                    Button {
                        camera.capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 60, height: 60)
                        }
                    }

                    Spacer()

                    // Camera flip button
                    Button {
                        camera.switchCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }

            if camera.isSaving {
                ProgressView()
                    .tint(.white)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { camera.checkAuthorizationAndStart() }
        .onDisappear { camera.stop() }
        .alert(
            "Camera Error",
            isPresented: Binding(
                get: { camera.error != nil },
                set: { if !$0 { camera.error = nil } }
            ),
            presenting: camera.error
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private var flashIconName: String {
        switch camera.flashMode {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }
}

#Preview {
    ContentView()
}
