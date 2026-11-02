import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var camera = CameraService()
    @StateObject private var location = LocationService()

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()

            VStack {
                Spacer()
                // Живой предпросмотр штампа.
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(StampRenderer.lines(date: ctx.date, locationLines: location.overlayLines)
                        .joined(separator: "\n"))
                        .font(.system(.footnote, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                controls.padding(.vertical, 24)
            }

            if camera.isProcessing {
                ProgressView("Обработка видео…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            camera.locationLinesProvider = { [location] in
                MainActor.assumeIsolated { location.overlayLines }
            }
            location.start()
            if await CameraService.requestPermissions() { camera.configure() }
        }
        .alert("Ошибка", isPresented: .constant(camera.lastError != nil)) {
            Button("OK") { camera.lastError = nil }
        } message: {
            Text(camera.lastError ?? "")
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            Picker("Режим", selection: $camera.mode) {
                Text("Фото").tag(CameraService.Mode.photo)
                Text("Видео").tag(CameraService.Mode.video)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .disabled(camera.isRecording)

            Button {
                camera.mode == .photo ? camera.capturePhoto() : camera.toggleRecording()
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 74, height: 74)
                    if camera.mode == .video {
                        RoundedRectangle(cornerRadius: camera.isRecording ? 6 : 30)
                            .fill(.red)
                            .frame(width: camera.isRecording ? 30 : 60, height: camera.isRecording ? 30 : 60)
                    } else {
                        Circle().fill(.white).frame(width: 60, height: 60)
                    }
                }
            }
            .disabled(camera.isProcessing)
        }
    }
}

/// Обёртка над AVCaptureVideoPreviewLayer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
