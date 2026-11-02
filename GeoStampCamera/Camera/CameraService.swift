import AVFoundation
import UIKit
import Photos

/// Управляет AVCaptureSession: фото, видео, сохранение в галерею со штампом.
final class CameraService: NSObject, ObservableObject {
    enum Mode { case photo, video }

    @Published var mode: Mode = .photo
    @Published private(set) var isRecording = false
    @Published private(set) var isProcessing = false
    @Published var lastError: String?

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()

    /// Источник строк локации — задаётся из UI.
    var locationLinesProvider: () -> [String] = { [] }
    private var recordingStart = Date()
    private var recordingLocationLines: [String] = []
    private var photoLocationLines: [String] = []
    private var photoDate = Date()

    // MARK: - Setup

    func configure() {
        sessionQueue.async { [self] in
            guard session.inputs.isEmpty else { return }
            session.beginConfiguration()
            session.sessionPreset = .high
            if let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: cam), session.canAddInput(input) {
                session.addInput(input)
            }
            if let mic = AVCaptureDevice.default(for: .audio),
               let input = try? AVCaptureDeviceInput(device: mic), session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
            session.commitConfiguration()
            session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [self] in session.stopRunning() }
    }

    static func requestPermissions() async -> Bool {
        let video = await AVCaptureDevice.requestAccess(for: .video)
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        return video
    }

    // MARK: - Photo

    func capturePhoto() {
        photoDate = Date()
        photoLocationLines = locationLinesProvider()
        sessionQueue.async { [self] in
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    // MARK: - Video

    func toggleRecording() {
        if isRecording {
            sessionQueue.async { [self] in movieOutput.stopRecording() }
            return
        }
        recordingStart = Date()
        recordingLocationLines = locationLinesProvider()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        isRecording = true
        sessionQueue.async { [self] in
            movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    // MARK: - Saving

    private func save(_ change: @escaping () -> Void) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            await report("Нет доступа к галерее")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges(change)
        } catch {
            await report(error.localizedDescription)
        }
    }

    @MainActor private func report(_ message: String) { lastError = message }
    @MainActor private func setProcessing(_ v: Bool) { isProcessing = v }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            Task { await report(error?.localizedDescription ?? "Не удалось получить фото") }
            return
        }
        let lines = StampRenderer.lines(date: photoDate, locationLines: photoLocationLines)
        let stamped = StampRenderer.stamp(image: image, lines: lines)
        Task {
            await save { PHAssetChangeRequest.creationRequestForAsset(from: stamped) }
        }
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in isRecording = false }
        Task {
            await setProcessing(true)
            defer { Task { await setProcessing(false) } }
            do {
                let stamped = try await StampRenderer.stampVideo(
                    at: outputFileURL, startDate: recordingStart, locationLines: recordingLocationLines)
                await save {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: stamped)
                }
                try? FileManager.default.removeItem(at: outputFileURL)
                try? FileManager.default.removeItem(at: stamped)
            } catch {
                await report(error.localizedDescription)
            }
        }
    }
}
