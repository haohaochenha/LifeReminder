import Foundation
import AVFoundation
import Combine

final class AudioRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var level: CGFloat = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var currentFile: URL?

    // MARK: - Permission

    func requestPermission(_ completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        default:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }

    // MARK: - Recording

    @discardableResult
    func start() -> Bool {
        guard !isRecording else { return true }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: [])
        } catch {
            errorMessage = "音频会话启动失败：\(error.localizedDescription)"
            return false
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("idea-\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record() else {
                errorMessage = "麦克风暂时不可用，请稍后再试"
                return false
            }
            self.recorder = recorder
            self.currentFile = url
            isRecording = true
            duration = 0
            level = 0
            startMetering()
            return true
        } catch {
            errorMessage = "无法开始录音：\(error.localizedDescription)"
            return false
        }
    }

    func stop() -> URL? {
        guard isRecording else { return currentFile }
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return currentFile
    }

    func cancel() {
        _ = stop()
        if let url = currentFile {
            try? FileManager.default.removeItem(at: url)
        }
        currentFile = nil
        duration = 0
    }

    func consumeFile(_ url: URL?) {
        guard let url = url else { return }
        try? FileManager.default.removeItem(at: url)
        if currentFile == url {
            currentFile = nil
        }
    }

    // MARK: - Metering

    private func startMetering() {
        meterTimer?.invalidate()
        let timer = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            let clamped = max(-52, min(0, power))
            let normalized = CGFloat((clamped + 52) / 52)
            self.level = normalized
            self.duration = recorder.currentTime
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }
}
