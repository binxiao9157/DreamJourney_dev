import AVFoundation
import Foundation
import Speech

final class EchoNativeSpeechCapture {
    enum CaptureError: LocalizedError {
        case recognitionPermissionDenied
        case recognizerUnavailable
        case audioInputUnavailable
        case noSpeechDetected
        case recognitionFailed

        var errorDescription: String? {
            switch self {
            case .recognitionPermissionDenied:
                return "需要语音识别权限，或使用文字回响"
            case .recognizerUnavailable:
                return "系统语音识别暂不可用，请使用文字回响"
            case .audioInputUnavailable:
                return "麦克风输入暂不可用，请稍后重试"
            case .noSpeechDetected:
                return "刚才没有听清，可以再说一次"
            case .recognitionFailed:
                return "语音识别失败，请重试或使用文字回响"
            }
        }
    }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestText = ""
    private var isCompleted = false
    private var hasInstalledTap = false
    private var completionFallbackWorkItem: DispatchWorkItem?

    private var onReady: (() -> Void)?
    private var onPartial: ((String) -> Void)?
    private var onFinal: ((String) -> Void)?
    private var onFailure: ((Error) -> Void)?

    deinit {
        cancel()
    }

    func start(
        onReady: @escaping () -> Void,
        onPartial: @escaping (String) -> Void,
        onFinal: @escaping (String) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        self.onReady = onReady
        self.onPartial = onPartial
        self.onFinal = onFinal
        self.onFailure = onFailure

        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            startAuthorizedCapture()
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard status == .authorized else {
                        self.completeFailure(CaptureError.recognitionPermissionDenied)
                        return
                    }
                    self.startAuthorizedCapture()
                }
            }
        case .denied, .restricted:
            completeFailure(CaptureError.recognitionPermissionDenied)
        @unknown default:
            completeFailure(CaptureError.recognitionPermissionDenied)
        }
    }

    func finish() {
        guard !isCompleted else { return }
        stopAudioInput()
        recognitionRequest?.endAudio()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isCompleted else { return }
            if self.latestText.isEmpty {
                self.completeFailure(CaptureError.noSpeechDetected)
            } else {
                self.completeFinal(self.latestText)
            }
        }
        completionFallbackWorkItem?.cancel()
        completionFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: workItem)
    }

    func cancel() {
        completionFallbackWorkItem?.cancel()
        completionFallbackWorkItem = nil
        stopAudioInput()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        clearCallbacks()
        isCompleted = true
    }

    private func startAuthorizedCapture() {
        guard !isCompleted,
              let recognizer,
              recognizer.isAvailable else {
            completeFailure(CaptureError.recognizerUnavailable)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            completeFailure(CaptureError.audioInputUnavailable)
            return
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasInstalledTap = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self, !self.isCompleted else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    self.latestText = text
                    DispatchQueue.main.async { [weak self] in
                        guard let self, !self.isCompleted else { return }
                        self.onPartial?(text)
                    }
                }
                if result.isFinal {
                    self.completeFinal(text)
                    return
                }
            }
            if error != nil {
                if self.latestText.isEmpty {
                    self.completeFailure(CaptureError.recognitionFailed)
                } else {
                    self.completeFinal(self.latestText)
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            onReady?()
        } catch {
            completeFailure(CaptureError.audioInputUnavailable)
        }
    }

    private func completeFinal(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isCompleted else { return }
        guard !normalized.isEmpty else {
            completeFailure(CaptureError.noSpeechDetected)
            return
        }
        isCompleted = true
        completionFallbackWorkItem?.cancel()
        stopAudioInput()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        let callback = onFinal
        clearCallbacks()
        DispatchQueue.main.async {
            callback?(normalized)
        }
    }

    private func completeFailure(_ error: Error) {
        guard !isCompleted else { return }
        isCompleted = true
        completionFallbackWorkItem?.cancel()
        stopAudioInput()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        let callback = onFailure
        clearCallbacks()
        DispatchQueue.main.async {
            callback?(error)
        }
    }

    private func stopAudioInput() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
    }

    private func clearCallbacks() {
        onReady = nil
        onPartial = nil
        onFinal = nil
        onFailure = nil
    }
}
